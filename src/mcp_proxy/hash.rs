//! SHA-256 helpers for the MCP airlock. Owner: worker LEDGER. NATIVE CHECK and FINITE TEST, not proved.
//!
//! The digest comes from `crate::pin::Sha256` (FIPS 180-4, std only). That type gives only a hex string as output,
//! and this module must not edit `src/airlock/pin.rs`, so `sha256` decodes the 64 hex digits back to 32 bytes.
//! The decode is a fixed nibble table step; it cannot fail on the output of `pin::Sha256::hex`.
pub type H16 = [u8; 16];

fn nibble(c: u8) -> Option<u8> {
    match c {
        b'0'..=b'9' => Some(c - b'0'),
        b'a'..=b'f' => Some(c - b'a' + 10),
        _ => None,
    }
}

/// SHA-256 of the concatenation of `parts` (use `crate::pin::Sha256`).
pub fn sha256(parts: &[&[u8]]) -> [u8; 32] {
    let mut h = crate::pin::Sha256::new();
    for p in parts {
        h.update(p);
    }
    let hex = h.hex();
    let b = hex.as_bytes();
    assert_eq!(b.len(), 64, "pin::Sha256::hex must give 64 digits");
    let mut out = [0u8; 32];
    for i in 0..32 {
        // pin::Sha256::hex writes lowercase hex with `{:08x}`; any other byte is a bug there, and we stop.
        let (Some(hi), Some(lo)) = (nibble(b[2 * i]), nibble(b[2 * i + 1])) else { panic!("pin::Sha256::hex gave a non-hex digit") };
        out[i] = (hi << 4) | lo;
    }
    out
}

/// First 16 bytes of `sha256(parts)`.
pub fn h16(parts: &[&[u8]]) -> H16 {
    let mut o = [0u8; 16];
    o.copy_from_slice(&sha256(parts)[..16]);
    o
}

pub fn hex(b: &[u8]) -> String {
    const D: &[u8; 16] = b"0123456789abcdef";
    let mut s = String::with_capacity(b.len() * 2);
    for x in b {
        s.push(D[(x >> 4) as usize] as char);
        s.push(D[(x & 15) as usize] as char);
    }
    s
}

/// Exactly 32 lowercase hex digits, else None.
pub fn unhex16(s: &str) -> Option<H16> {
    let b = s.as_bytes();
    if b.len() != 32 {
        return None;
    }
    let mut o = [0u8; 16];
    for i in 0..16 {
        o[i] = (nibble(b[2 * i])? << 4) | nibble(b[2 * i + 1])?;
    }
    Some(o)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sha256_known_vectors() {
        // FIPS 180-4 / NIST CSRC examples and the common empty-string vector.
        assert_eq!(hex(&sha256(&[])), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
        assert_eq!(hex(&sha256(&[b"abc"])), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        assert_eq!(hex(&sha256(&[b"a", b"b", b"c"])), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        assert_eq!(
            hex(&sha256(&[b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"])),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        );
        assert_eq!(
            hex(&sha256(&[b"abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"])),
            "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1"
        );
        let mil = vec![b'a'; 1_000_000];
        assert_eq!(hex(&sha256(&[&mil])), "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0");
        assert_eq!(hex(&h16(&[b"abc"])), "ba7816bf8f01cfea414140de5dae2223");
    }

    #[test]
    fn unhex16_rules() {
        assert_eq!(unhex16("ba7816bf8f01cfea414140de5dae2223"), Some(h16(&[b"abc"])));
        assert_eq!(unhex16("BA7816BF8F01CFEA414140DE5DAE2223"), None);
        assert_eq!(unhex16("ba7816bf8f01cfea414140de5dae222"), None);
        assert_eq!(unhex16("ba7816bf8f01cfea414140de5dae22230"), None);
        assert_eq!(unhex16("ba7816bf8f01cfea414140de5dae222g"), None);
        assert_eq!(unhex16("+a7816bf8f01cfea414140de5dae2223"), None);
    }
}
