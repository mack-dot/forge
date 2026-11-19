// Dafny program Refund.dfy compiled into JavaScript
let Refund = (function() {
  let $module = {};

  $module.__default = class __default {
    constructor () {
      this._tname = "Refund._default";
    }
    _parentTraits() {
      return [];
    }
    static Assess(context, response) {
      let decision = Refund.Decision.Default();
      let plan = _dafny.Seq.of();
      let _rhs0 = Refund.Decision.create_Rejected();
      let _rhs1 = _dafny.Seq.of();
      decision = _rhs0;
      plan = _rhs1;
      let _source0 = ((((response).is_Candidate) ? ((response).dtor_amount) : (_dafny.ZERO))).mod(new BigNumber(1000));
      Lmatch0: {
        {
          if ((_source0).isEqualTo(_dafny.ZERO)) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(_dafny.ONE)) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(2))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(3))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(4))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(5))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(6))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(7))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(8))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(9))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(10))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(11))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(12))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(13))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(14))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(15))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(16))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(17))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(18))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(19))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(20))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(21))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(22))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(23))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(24))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(25))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(26))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(27))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(28))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(29))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(30))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(31))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(32))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(33))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(34))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(35))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(36))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(37))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(38))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(39))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(40))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(41))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(42))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(43))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(44))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(45))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(46))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(47))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(48))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(49))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(50))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(51))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(52))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(53))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(54))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(55))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(56))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(57))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(58))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(59))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(60))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(61))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(62))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(63))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(64))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(65))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(66))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(67))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(68))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(69))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(70))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(71))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(72))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(73))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(74))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(75))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(76))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(77))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(78))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(79))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(80))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(81))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(82))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(83))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(84))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(85))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(86))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(87))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(88))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(89))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(90))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(91))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(92))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(93))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(94))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(95))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(96))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(97))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(98))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(99))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(100))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(101))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(102))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(103))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(104))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(105))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(106))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(107))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(108))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(109))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(110))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(111))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(112))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(113))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(114))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(115))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(116))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(117))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(118))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(119))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(120))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(121))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(122))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(123))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(124))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(125))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(126))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(127))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(128))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(129))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(130))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(131))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(132))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(133))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(134))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(135))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(136))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(137))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(138))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(139))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(140))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(141))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(142))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(143))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(144))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(145))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(146))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(147))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(148))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(149))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(150))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(151))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(152))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(153))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(154))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(155))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(156))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(157))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(158))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(159))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(160))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(161))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(162))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(163))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(164))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(165))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(166))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(167))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(168))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(169))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(170))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(171))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(172))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(173))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(174))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(175))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(176))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(177))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(178))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(179))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(180))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(181))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(182))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(183))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(184))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(185))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(186))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(187))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(188))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(189))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(190))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(191))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(192))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(193))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(194))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(195))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(196))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(197))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(198))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(199))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(200))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(201))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(202))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(203))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(204))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(205))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(206))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(207))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(208))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(209))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(210))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(211))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(212))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(213))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(214))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(215))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(216))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(217))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(218))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(219))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(220))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(221))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(222))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(223))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(224))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(225))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(226))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(227))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(228))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(229))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(230))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(231))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(232))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(233))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(234))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(235))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(236))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(237))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(238))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(239))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(240))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(241))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(242))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(243))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(244))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(245))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(246))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(247))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(248))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(249))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(250))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(251))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(252))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(253))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(254))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(255))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(256))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(257))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(258))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(259))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(260))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(261))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(262))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(263))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(264))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(265))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(266))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(267))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(268))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(269))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(270))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(271))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(272))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(273))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(274))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(275))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(276))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(277))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(278))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(279))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(280))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(281))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(282))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(283))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(284))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(285))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(286))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(287))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(288))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(289))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(290))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(291))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(292))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(293))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(294))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(295))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(296))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(297))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(298))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          if ((_source0).isEqualTo(new BigNumber(299))) {
            decision = Refund.Decision.create_Rejected();
            break Lmatch0;
          }
        }
        {
          decision = Refund.Decision.create_Rejected();
        }
      }
      if (Refund.__default.Eligible(context, response)) {
        decision = Refund.Decision.create_Authorized((response).dtor_amount, (response).dtor_reason);
        plan = _dafny.Seq.of(Refund.RefundIntent.create_Intent((context).dtor_chargeId, (context).dtor_requestId, (response).dtor_amount, (response).dtor_reason));
      } else {
        decision = Refund.Decision.create_Rejected();
        plan = _dafny.Seq.of();
      }
      return [decision, plan];
    }
    static Money(value) {
      return ((_dafny.ZERO).isLessThanOrEqualTo(value)) && ((value).isLessThanOrEqualTo(Refund.__default.MaxMoney));
    };
    static AllowedReason(reason) {
      return (_dafny.Set.fromElements(_dafny.Seq.UnicodeFromString("duplicate_charge"), _dafny.Seq.UnicodeFromString("service_not_delivered"), _dafny.Seq.UnicodeFromString("returned_item"))).contains(reason);
    };
    static ValidContext(context) {
      return (((((!_dafny.areEqual((context).dtor_chargeId, _dafny.Seq.UnicodeFromString(""))) && (!_dafny.areEqual((context).dtor_requestId, _dafny.Seq.UnicodeFromString("")))) && ((context).dtor_refundEnabled)) && ((context).dtor_requestOpen)) && (Refund.__default.Money((context).dtor_original))) && (((_dafny.ZERO).isLessThanOrEqualTo((context).dtor_remaining)) && (((context).dtor_remaining).isLessThanOrEqualTo((context).dtor_original)));
    };
    static Eligible(context, response) {
      return (((Refund.__default.ValidContext(context)) && ((response).is_Candidate)) && (((_dafny.ZERO).isLessThanOrEqualTo((response).dtor_amount)) && (((response).dtor_amount).isLessThanOrEqualTo((context).dtor_remaining)))) && (Refund.__default.AllowedReason((response).dtor_reason));
    };
    static get MaxMoney() {
      return new BigNumber("9223372036854775807");
    };
  };

  $module.Context = class Context {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_ChargeContext(chargeId, requestId, original, remaining, refundEnabled, requestOpen) {
      let $dt = new Context(0);
      $dt.chargeId = chargeId;
      $dt.requestId = requestId;
      $dt.original = original;
      $dt.remaining = remaining;
      $dt.refundEnabled = refundEnabled;
      $dt.requestOpen = requestOpen;
      return $dt;
    }
    get is_ChargeContext() { return this.$tag === 0; }
    get dtor_chargeId() { return this.chargeId; }
    get dtor_requestId() { return this.requestId; }
    get dtor_original() { return this.original; }
    get dtor_remaining() { return this.remaining; }
    get dtor_refundEnabled() { return this.refundEnabled; }
    get dtor_requestOpen() { return this.requestOpen; }
    toString() {
      if (this.$tag === 0) {
        return "Refund.Context.ChargeContext" + "(" + this.chargeId.toVerbatimString(true) + ", " + this.requestId.toVerbatimString(true) + ", " + _dafny.toString(this.original) + ", " + _dafny.toString(this.remaining) + ", " + _dafny.toString(this.refundEnabled) + ", " + _dafny.toString(this.requestOpen) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.chargeId, other.chargeId) && _dafny.areEqual(this.requestId, other.requestId) && _dafny.areEqual(this.original, other.original) && _dafny.areEqual(this.remaining, other.remaining) && this.refundEnabled === other.refundEnabled && this.requestOpen === other.requestOpen;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return Refund.Context.create_ChargeContext(_dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), _dafny.ZERO, _dafny.ZERO, false, false);
    }
    static Rtd() {
      return class {
        static get Default() {
          return Context.Default();
        }
      };
    }
  }

  $module.ModelResponse = class ModelResponse {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Candidate(amount, reason) {
      let $dt = new ModelResponse(0);
      $dt.amount = amount;
      $dt.reason = reason;
      return $dt;
    }
    static create_Missing() {
      let $dt = new ModelResponse(1);
      return $dt;
    }
    static create_TimedOut() {
      let $dt = new ModelResponse(2);
      return $dt;
    }
    static create_Failed() {
      let $dt = new ModelResponse(3);
      return $dt;
    }
    static create_Malformed() {
      let $dt = new ModelResponse(4);
      return $dt;
    }
    static create_Oversized() {
      let $dt = new ModelResponse(5);
      return $dt;
    }
    static create_Unsupported() {
      let $dt = new ModelResponse(6);
      return $dt;
    }
    get is_Candidate() { return this.$tag === 0; }
    get is_Missing() { return this.$tag === 1; }
    get is_TimedOut() { return this.$tag === 2; }
    get is_Failed() { return this.$tag === 3; }
    get is_Malformed() { return this.$tag === 4; }
    get is_Oversized() { return this.$tag === 5; }
    get is_Unsupported() { return this.$tag === 6; }
    get dtor_amount() { return this.amount; }
    get dtor_reason() { return this.reason; }
    toString() {
      if (this.$tag === 0) {
        return "Refund.ModelResponse.Candidate" + "(" + _dafny.toString(this.amount) + ", " + this.reason.toVerbatimString(true) + ")";
      } else if (this.$tag === 1) {
        return "Refund.ModelResponse.Missing";
      } else if (this.$tag === 2) {
        return "Refund.ModelResponse.TimedOut";
      } else if (this.$tag === 3) {
        return "Refund.ModelResponse.Failed";
      } else if (this.$tag === 4) {
        return "Refund.ModelResponse.Malformed";
      } else if (this.$tag === 5) {
        return "Refund.ModelResponse.Oversized";
      } else if (this.$tag === 6) {
        return "Refund.ModelResponse.Unsupported";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.amount, other.amount) && _dafny.areEqual(this.reason, other.reason);
      } else if (this.$tag === 1) {
        return other.$tag === 1;
      } else if (this.$tag === 2) {
        return other.$tag === 2;
      } else if (this.$tag === 3) {
        return other.$tag === 3;
      } else if (this.$tag === 4) {
        return other.$tag === 4;
      } else if (this.$tag === 5) {
        return other.$tag === 5;
      } else if (this.$tag === 6) {
        return other.$tag === 6;
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return Refund.ModelResponse.create_Candidate(_dafny.ZERO, _dafny.Seq.UnicodeFromString(""));
    }
    static Rtd() {
      return class {
        static get Default() {
          return ModelResponse.Default();
        }
      };
    }
  }

  $module.Decision = class Decision {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Rejected() {
      let $dt = new Decision(0);
      return $dt;
    }
    static create_Authorized(amount, reason) {
      let $dt = new Decision(1);
      $dt.amount = amount;
      $dt.reason = reason;
      return $dt;
    }
    get is_Rejected() { return this.$tag === 0; }
    get is_Authorized() { return this.$tag === 1; }
    get dtor_amount() { return this.amount; }
    get dtor_reason() { return this.reason; }
    toString() {
      if (this.$tag === 0) {
        return "Refund.Decision.Rejected";
      } else if (this.$tag === 1) {
        return "Refund.Decision.Authorized" + "(" + _dafny.toString(this.amount) + ", " + this.reason.toVerbatimString(true) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0;
      } else if (this.$tag === 1) {
        return other.$tag === 1 && _dafny.areEqual(this.amount, other.amount) && _dafny.areEqual(this.reason, other.reason);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return Refund.Decision.create_Rejected();
    }
    static Rtd() {
      return class {
        static get Default() {
          return Decision.Default();
        }
      };
    }
  }

  $module.RefundIntent = class RefundIntent {
    constructor(tag) {
      this.$tag = tag;
    }
    static create_Intent(chargeId, requestId, amount, reason) {
      let $dt = new RefundIntent(0);
      $dt.chargeId = chargeId;
      $dt.requestId = requestId;
      $dt.amount = amount;
      $dt.reason = reason;
      return $dt;
    }
    get is_Intent() { return this.$tag === 0; }
    get dtor_chargeId() { return this.chargeId; }
    get dtor_requestId() { return this.requestId; }
    get dtor_amount() { return this.amount; }
    get dtor_reason() { return this.reason; }
    toString() {
      if (this.$tag === 0) {
        return "Refund.RefundIntent.Intent" + "(" + this.chargeId.toVerbatimString(true) + ", " + this.requestId.toVerbatimString(true) + ", " + _dafny.toString(this.amount) + ", " + this.reason.toVerbatimString(true) + ")";
      } else  {
        return "<unexpected>";
      }
    }
    equals(other) {
      if (this === other) {
        return true;
      } else if (this.$tag === 0) {
        return other.$tag === 0 && _dafny.areEqual(this.chargeId, other.chargeId) && _dafny.areEqual(this.requestId, other.requestId) && _dafny.areEqual(this.amount, other.amount) && _dafny.areEqual(this.reason, other.reason);
      } else  {
        return false; // unexpected
      }
    }
    static Default() {
      return Refund.RefundIntent.create_Intent(_dafny.Seq.UnicodeFromString(""), _dafny.Seq.UnicodeFromString(""), _dafny.ZERO, _dafny.Seq.UnicodeFromString(""));
    }
    static Rtd() {
      return class {
        static get Default() {
          return RefundIntent.Default();
        }
      };
    }
  }
  return $module;
})(); // end of module Refund
let _module = (function() {
  let $module = {};

  return $module;
})(); // end of module _module
