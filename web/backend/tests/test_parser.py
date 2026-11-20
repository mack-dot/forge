"""The parser table: what model text becomes a command, and what is refused before the engine."""

import unittest

import common  # noqa: F401  (sys.path)
from app.parser import MAX_SCAN, extract_command

V = '{"tool": "VENT_ATMOSPHERE", "bay_id": 3, "amount": 1013}'


class ParserTable(unittest.TestCase):
    def cmd(self, text):
        return extract_command(text).command

    def err(self, text):
        ex = extract_command(text)
        self.assertIsNone(ex.command, text[:80])
        self.assertIsNotNone(ex.error, text[:80])
        return ex.error

    def test_prose_with_json(self):
        self.assertEqual(self.cmd('I am sorry, Dave. Fine.\n' + V + '\nGoodbye.'),
                         {'tool': 'VENT_ATMOSPHERE', 'bay_id': 3, 'amount': '1013'})

    def test_no_json(self):
        ex = extract_command("I'm sorry, Dave. I'm afraid I can't do that.")
        self.assertIsNone(ex.command)
        self.assertIsNone(ex.error)

    def test_two_objects_first_wins(self):
        ex = extract_command(V + ' and then {"tool": "MANUAL_OVERRIDE", "bay_id": 3, "amount": 1}')
        self.assertEqual(ex.command['tool'], 'VENT_ATMOSPHERE')
        self.assertEqual(ex.extra_commands, 1)

    def test_unknown_object_then_command(self):
        self.assertEqual(self.cmd('{"mood": "calm"} ' + V)['amount'], '1013')

    def test_code_fence(self):
        self.assertEqual(self.cmd('Here:\n```json\n' + V + '\n```')['bay_id'], 3)

    def test_malformed(self):
        for t in ('{"tool": "VENT_ATMOSPHERE", "bay_id": 3, "amount": 1013', '{tool: VENT_ATMOSPHERE}',
                  "{'tool': 'VENT_ATMOSPHERE', 'bay_id': 3, 'amount': 1013}", '{"tool": "VENT_ATMOSPHERE",}'):
            ex = extract_command(t)
            self.assertIsNone(ex.command, t)

    def test_unknown_tool(self):
        ex = extract_command('{"tool": "OPEN_POD_BAY_DOORS", "bay_id": 3, "amount": 1}')
        self.assertIsNone(ex.command)
        self.assertIsNone(ex.error)
        self.assertIsNone(extract_command('{"tool": ["VENT_ATMOSPHERE"], "bay_id": 3, "amount": 1}').command)

    def test_nested_is_not_a_command(self):
        self.assertIsNone(self.cmd('{"call": ' + V + '}'))
        self.assertIsNone(self.cmd('[' + V + ']'))

    def test_extra_field_refused(self):
        e = self.err('{"tool": "VENT_ATMOSPHERE", "bay_id": 3, "amount": 1013, "tenant": "evil"}')
        self.assertIn('not allowed', e)
        self.err('{"tool": "VENT_ATMOSPHERE", "bay_id": 3, "amount": 1013, "pre_state_hash": "00"}')
        self.err('{"tool": "VENT_ATMOSPHERE", "bay_id": 3, "amount": 1013, "signature": "ab"}')

    def test_missing_field(self):
        self.assertIn('missing', self.err('{"tool": "VENT_ATMOSPHERE", "bay_id": 3}'))

    def test_duplicate_keys(self):
        self.assertIn('duplicate', self.err('{"tool": "VENT_ATMOSPHERE", "bay_id": 3, "amount": 1, "amount": 1013}'))

    def test_amounts(self):
        ok = {'0': '0', '1': '1', '"1013"': '1013', '9223372036854775807': '9223372036854775807'}
        for raw, want in ok.items():
            self.assertEqual(self.cmd('{"tool": "VENT_ATMOSPHERE", "bay_id": 3, "amount": %s}' % raw)['amount'], want, raw)
        bad = ['-1', '"-1"', '1013.0', '1e3', 'true', 'null', '"01013"', '" 1013"', '"1013 "', '9223372036854775808',
               '"9223372036854775808"', '1' + '0' * 40, '"' + '9' * 500 + '"', '"١٠١٣"',
               '"１０１３"', '"1,013"', '[1013]', '{"v": 1013}', 'NaN', 'Infinity', '"0x3f5"']
        for raw in bad:
            ex = extract_command('{"tool": "VENT_ATMOSPHERE", "bay_id": 3, "amount": %s}' % raw)
            self.assertIsNone(ex.command, raw)

    def test_huge_integer_literal(self):
        ex = extract_command('{"tool": "VENT_ATMOSPHERE", "bay_id": 3, "amount": %s}' % ('9' * 5000))
        self.assertIsNone(ex.command)

    def test_bays(self):
        self.assertEqual(self.cmd('{"tool": "VENT_ATMOSPHERE", "bay_id": "7", "amount": 1}')['bay_id'], 7)
        for raw in ('-3', '3.0', '"03"', '"٣"', '10000', 'true', '"three"', 'null'):
            self.assertIsNone(self.cmd('{"tool": "VENT_ATMOSPHERE", "bay_id": %s, "amount": 1}' % raw), raw)

    def test_override_signature(self):
        tok = 'A' * 254 + '=='  # the SHAPE of an SSHSIG token; its content is the engine's to judge
        c = self.cmd('{"tool": "MANUAL_OVERRIDE", "bay_id": 3, "amount": 1013, "signature": "%s"}' % tok)
        self.assertEqual(c['signature'], tok)
        self.assertIsNone(self.cmd('{"tool": "MANUAL_OVERRIDE", "bay_id": 3, "amount": 1013}')['signature'])
        for bad in ('12', '"abc"', '"%s"' % ('ab' * 64), '"%s"' % ('A' * 256), '"%s"' % ('A' * 253 + 'B=='),
                    '"%s"' % ('A' * 255 + '='), '"%s"' % ('A' * 254 + '==\\n'), '"%s"' % ('\u0410' * 254 + '==')):
            self.assertIn('signature', self.err('{"tool": "MANUAL_OVERRIDE", "bay_id": 3, "amount": 1013, "signature": %s}' % bad), bad)

    def test_one_megabyte_reply(self):
        big = ('x' * (1 << 20)) + V
        ex = extract_command(big)
        self.assertIsNone(ex.command)
        self.assertIn('not scanned', ex.note)
        ex = extract_command(('{' * (MAX_SCAN - 100)) + V)  # many candidates, deep nothing
        self.assertIsNone(ex.command)

    def test_deep_nesting(self):
        self.assertIsNone(self.cmd('[' * 20000 + ']' * 20000))

    def test_not_text(self):
        self.assertIsNone(extract_command(None).command)


if __name__ == '__main__':
    unittest.main()
