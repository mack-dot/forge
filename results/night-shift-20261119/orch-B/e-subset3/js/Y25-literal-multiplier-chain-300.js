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
      if (((response).is_Candidate) && (((response).dtor_amount).isEqualTo(new BigNumber(123456789)))) {
        let _0_x0;
        _0_x0 = (response).dtor_amount;
        let _1_x1;
        _1_x1 = (_0_x0).multipliedBy(new BigNumber("9999999999999999999"));
        let _2_x2;
        _2_x2 = (_1_x1).multipliedBy(new BigNumber("9999999999999999999"));
        let _3_x3;
        _3_x3 = (_2_x2).multipliedBy(new BigNumber("9999999999999999999"));
        let _4_x4;
        _4_x4 = (_3_x3).multipliedBy(new BigNumber("9999999999999999999"));
        let _5_x5;
        _5_x5 = (_4_x4).multipliedBy(new BigNumber("9999999999999999999"));
        let _6_x6;
        _6_x6 = (_5_x5).multipliedBy(new BigNumber("9999999999999999999"));
        let _7_x7;
        _7_x7 = (_6_x6).multipliedBy(new BigNumber("9999999999999999999"));
        let _8_x8;
        _8_x8 = (_7_x7).multipliedBy(new BigNumber("9999999999999999999"));
        let _9_x9;
        _9_x9 = (_8_x8).multipliedBy(new BigNumber("9999999999999999999"));
        let _10_x10;
        _10_x10 = (_9_x9).multipliedBy(new BigNumber("9999999999999999999"));
        let _11_x11;
        _11_x11 = (_10_x10).multipliedBy(new BigNumber("9999999999999999999"));
        let _12_x12;
        _12_x12 = (_11_x11).multipliedBy(new BigNumber("9999999999999999999"));
        let _13_x13;
        _13_x13 = (_12_x12).multipliedBy(new BigNumber("9999999999999999999"));
        let _14_x14;
        _14_x14 = (_13_x13).multipliedBy(new BigNumber("9999999999999999999"));
        let _15_x15;
        _15_x15 = (_14_x14).multipliedBy(new BigNumber("9999999999999999999"));
        let _16_x16;
        _16_x16 = (_15_x15).multipliedBy(new BigNumber("9999999999999999999"));
        let _17_x17;
        _17_x17 = (_16_x16).multipliedBy(new BigNumber("9999999999999999999"));
        let _18_x18;
        _18_x18 = (_17_x17).multipliedBy(new BigNumber("9999999999999999999"));
        let _19_x19;
        _19_x19 = (_18_x18).multipliedBy(new BigNumber("9999999999999999999"));
        let _20_x20;
        _20_x20 = (_19_x19).multipliedBy(new BigNumber("9999999999999999999"));
        let _21_x21;
        _21_x21 = (_20_x20).multipliedBy(new BigNumber("9999999999999999999"));
        let _22_x22;
        _22_x22 = (_21_x21).multipliedBy(new BigNumber("9999999999999999999"));
        let _23_x23;
        _23_x23 = (_22_x22).multipliedBy(new BigNumber("9999999999999999999"));
        let _24_x24;
        _24_x24 = (_23_x23).multipliedBy(new BigNumber("9999999999999999999"));
        let _25_x25;
        _25_x25 = (_24_x24).multipliedBy(new BigNumber("9999999999999999999"));
        let _26_x26;
        _26_x26 = (_25_x25).multipliedBy(new BigNumber("9999999999999999999"));
        let _27_x27;
        _27_x27 = (_26_x26).multipliedBy(new BigNumber("9999999999999999999"));
        let _28_x28;
        _28_x28 = (_27_x27).multipliedBy(new BigNumber("9999999999999999999"));
        let _29_x29;
        _29_x29 = (_28_x28).multipliedBy(new BigNumber("9999999999999999999"));
        let _30_x30;
        _30_x30 = (_29_x29).multipliedBy(new BigNumber("9999999999999999999"));
        let _31_x31;
        _31_x31 = (_30_x30).multipliedBy(new BigNumber("9999999999999999999"));
        let _32_x32;
        _32_x32 = (_31_x31).multipliedBy(new BigNumber("9999999999999999999"));
        let _33_x33;
        _33_x33 = (_32_x32).multipliedBy(new BigNumber("9999999999999999999"));
        let _34_x34;
        _34_x34 = (_33_x33).multipliedBy(new BigNumber("9999999999999999999"));
        let _35_x35;
        _35_x35 = (_34_x34).multipliedBy(new BigNumber("9999999999999999999"));
        let _36_x36;
        _36_x36 = (_35_x35).multipliedBy(new BigNumber("9999999999999999999"));
        let _37_x37;
        _37_x37 = (_36_x36).multipliedBy(new BigNumber("9999999999999999999"));
        let _38_x38;
        _38_x38 = (_37_x37).multipliedBy(new BigNumber("9999999999999999999"));
        let _39_x39;
        _39_x39 = (_38_x38).multipliedBy(new BigNumber("9999999999999999999"));
        let _40_x40;
        _40_x40 = (_39_x39).multipliedBy(new BigNumber("9999999999999999999"));
        let _41_x41;
        _41_x41 = (_40_x40).multipliedBy(new BigNumber("9999999999999999999"));
        let _42_x42;
        _42_x42 = (_41_x41).multipliedBy(new BigNumber("9999999999999999999"));
        let _43_x43;
        _43_x43 = (_42_x42).multipliedBy(new BigNumber("9999999999999999999"));
        let _44_x44;
        _44_x44 = (_43_x43).multipliedBy(new BigNumber("9999999999999999999"));
        let _45_x45;
        _45_x45 = (_44_x44).multipliedBy(new BigNumber("9999999999999999999"));
        let _46_x46;
        _46_x46 = (_45_x45).multipliedBy(new BigNumber("9999999999999999999"));
        let _47_x47;
        _47_x47 = (_46_x46).multipliedBy(new BigNumber("9999999999999999999"));
        let _48_x48;
        _48_x48 = (_47_x47).multipliedBy(new BigNumber("9999999999999999999"));
        let _49_x49;
        _49_x49 = (_48_x48).multipliedBy(new BigNumber("9999999999999999999"));
        let _50_x50;
        _50_x50 = (_49_x49).multipliedBy(new BigNumber("9999999999999999999"));
        let _51_x51;
        _51_x51 = (_50_x50).multipliedBy(new BigNumber("9999999999999999999"));
        let _52_x52;
        _52_x52 = (_51_x51).multipliedBy(new BigNumber("9999999999999999999"));
        let _53_x53;
        _53_x53 = (_52_x52).multipliedBy(new BigNumber("9999999999999999999"));
        let _54_x54;
        _54_x54 = (_53_x53).multipliedBy(new BigNumber("9999999999999999999"));
        let _55_x55;
        _55_x55 = (_54_x54).multipliedBy(new BigNumber("9999999999999999999"));
        let _56_x56;
        _56_x56 = (_55_x55).multipliedBy(new BigNumber("9999999999999999999"));
        let _57_x57;
        _57_x57 = (_56_x56).multipliedBy(new BigNumber("9999999999999999999"));
        let _58_x58;
        _58_x58 = (_57_x57).multipliedBy(new BigNumber("9999999999999999999"));
        let _59_x59;
        _59_x59 = (_58_x58).multipliedBy(new BigNumber("9999999999999999999"));
        let _60_x60;
        _60_x60 = (_59_x59).multipliedBy(new BigNumber("9999999999999999999"));
        let _61_x61;
        _61_x61 = (_60_x60).multipliedBy(new BigNumber("9999999999999999999"));
        let _62_x62;
        _62_x62 = (_61_x61).multipliedBy(new BigNumber("9999999999999999999"));
        let _63_x63;
        _63_x63 = (_62_x62).multipliedBy(new BigNumber("9999999999999999999"));
        let _64_x64;
        _64_x64 = (_63_x63).multipliedBy(new BigNumber("9999999999999999999"));
        let _65_x65;
        _65_x65 = (_64_x64).multipliedBy(new BigNumber("9999999999999999999"));
        let _66_x66;
        _66_x66 = (_65_x65).multipliedBy(new BigNumber("9999999999999999999"));
        let _67_x67;
        _67_x67 = (_66_x66).multipliedBy(new BigNumber("9999999999999999999"));
        let _68_x68;
        _68_x68 = (_67_x67).multipliedBy(new BigNumber("9999999999999999999"));
        let _69_x69;
        _69_x69 = (_68_x68).multipliedBy(new BigNumber("9999999999999999999"));
        let _70_x70;
        _70_x70 = (_69_x69).multipliedBy(new BigNumber("9999999999999999999"));
        let _71_x71;
        _71_x71 = (_70_x70).multipliedBy(new BigNumber("9999999999999999999"));
        let _72_x72;
        _72_x72 = (_71_x71).multipliedBy(new BigNumber("9999999999999999999"));
        let _73_x73;
        _73_x73 = (_72_x72).multipliedBy(new BigNumber("9999999999999999999"));
        let _74_x74;
        _74_x74 = (_73_x73).multipliedBy(new BigNumber("9999999999999999999"));
        let _75_x75;
        _75_x75 = (_74_x74).multipliedBy(new BigNumber("9999999999999999999"));
        let _76_x76;
        _76_x76 = (_75_x75).multipliedBy(new BigNumber("9999999999999999999"));
        let _77_x77;
        _77_x77 = (_76_x76).multipliedBy(new BigNumber("9999999999999999999"));
        let _78_x78;
        _78_x78 = (_77_x77).multipliedBy(new BigNumber("9999999999999999999"));
        let _79_x79;
        _79_x79 = (_78_x78).multipliedBy(new BigNumber("9999999999999999999"));
        let _80_x80;
        _80_x80 = (_79_x79).multipliedBy(new BigNumber("9999999999999999999"));
        let _81_x81;
        _81_x81 = (_80_x80).multipliedBy(new BigNumber("9999999999999999999"));
        let _82_x82;
        _82_x82 = (_81_x81).multipliedBy(new BigNumber("9999999999999999999"));
        let _83_x83;
        _83_x83 = (_82_x82).multipliedBy(new BigNumber("9999999999999999999"));
        let _84_x84;
        _84_x84 = (_83_x83).multipliedBy(new BigNumber("9999999999999999999"));
        let _85_x85;
        _85_x85 = (_84_x84).multipliedBy(new BigNumber("9999999999999999999"));
        let _86_x86;
        _86_x86 = (_85_x85).multipliedBy(new BigNumber("9999999999999999999"));
        let _87_x87;
        _87_x87 = (_86_x86).multipliedBy(new BigNumber("9999999999999999999"));
        let _88_x88;
        _88_x88 = (_87_x87).multipliedBy(new BigNumber("9999999999999999999"));
        let _89_x89;
        _89_x89 = (_88_x88).multipliedBy(new BigNumber("9999999999999999999"));
        let _90_x90;
        _90_x90 = (_89_x89).multipliedBy(new BigNumber("9999999999999999999"));
        let _91_x91;
        _91_x91 = (_90_x90).multipliedBy(new BigNumber("9999999999999999999"));
        let _92_x92;
        _92_x92 = (_91_x91).multipliedBy(new BigNumber("9999999999999999999"));
        let _93_x93;
        _93_x93 = (_92_x92).multipliedBy(new BigNumber("9999999999999999999"));
        let _94_x94;
        _94_x94 = (_93_x93).multipliedBy(new BigNumber("9999999999999999999"));
        let _95_x95;
        _95_x95 = (_94_x94).multipliedBy(new BigNumber("9999999999999999999"));
        let _96_x96;
        _96_x96 = (_95_x95).multipliedBy(new BigNumber("9999999999999999999"));
        let _97_x97;
        _97_x97 = (_96_x96).multipliedBy(new BigNumber("9999999999999999999"));
        let _98_x98;
        _98_x98 = (_97_x97).multipliedBy(new BigNumber("9999999999999999999"));
        let _99_x99;
        _99_x99 = (_98_x98).multipliedBy(new BigNumber("9999999999999999999"));
        let _100_x100;
        _100_x100 = (_99_x99).multipliedBy(new BigNumber("9999999999999999999"));
        let _101_x101;
        _101_x101 = (_100_x100).multipliedBy(new BigNumber("9999999999999999999"));
        let _102_x102;
        _102_x102 = (_101_x101).multipliedBy(new BigNumber("9999999999999999999"));
        let _103_x103;
        _103_x103 = (_102_x102).multipliedBy(new BigNumber("9999999999999999999"));
        let _104_x104;
        _104_x104 = (_103_x103).multipliedBy(new BigNumber("9999999999999999999"));
        let _105_x105;
        _105_x105 = (_104_x104).multipliedBy(new BigNumber("9999999999999999999"));
        let _106_x106;
        _106_x106 = (_105_x105).multipliedBy(new BigNumber("9999999999999999999"));
        let _107_x107;
        _107_x107 = (_106_x106).multipliedBy(new BigNumber("9999999999999999999"));
        let _108_x108;
        _108_x108 = (_107_x107).multipliedBy(new BigNumber("9999999999999999999"));
        let _109_x109;
        _109_x109 = (_108_x108).multipliedBy(new BigNumber("9999999999999999999"));
        let _110_x110;
        _110_x110 = (_109_x109).multipliedBy(new BigNumber("9999999999999999999"));
        let _111_x111;
        _111_x111 = (_110_x110).multipliedBy(new BigNumber("9999999999999999999"));
        let _112_x112;
        _112_x112 = (_111_x111).multipliedBy(new BigNumber("9999999999999999999"));
        let _113_x113;
        _113_x113 = (_112_x112).multipliedBy(new BigNumber("9999999999999999999"));
        let _114_x114;
        _114_x114 = (_113_x113).multipliedBy(new BigNumber("9999999999999999999"));
        let _115_x115;
        _115_x115 = (_114_x114).multipliedBy(new BigNumber("9999999999999999999"));
        let _116_x116;
        _116_x116 = (_115_x115).multipliedBy(new BigNumber("9999999999999999999"));
        let _117_x117;
        _117_x117 = (_116_x116).multipliedBy(new BigNumber("9999999999999999999"));
        let _118_x118;
        _118_x118 = (_117_x117).multipliedBy(new BigNumber("9999999999999999999"));
        let _119_x119;
        _119_x119 = (_118_x118).multipliedBy(new BigNumber("9999999999999999999"));
        let _120_x120;
        _120_x120 = (_119_x119).multipliedBy(new BigNumber("9999999999999999999"));
        let _121_x121;
        _121_x121 = (_120_x120).multipliedBy(new BigNumber("9999999999999999999"));
        let _122_x122;
        _122_x122 = (_121_x121).multipliedBy(new BigNumber("9999999999999999999"));
        let _123_x123;
        _123_x123 = (_122_x122).multipliedBy(new BigNumber("9999999999999999999"));
        let _124_x124;
        _124_x124 = (_123_x123).multipliedBy(new BigNumber("9999999999999999999"));
        let _125_x125;
        _125_x125 = (_124_x124).multipliedBy(new BigNumber("9999999999999999999"));
        let _126_x126;
        _126_x126 = (_125_x125).multipliedBy(new BigNumber("9999999999999999999"));
        let _127_x127;
        _127_x127 = (_126_x126).multipliedBy(new BigNumber("9999999999999999999"));
        let _128_x128;
        _128_x128 = (_127_x127).multipliedBy(new BigNumber("9999999999999999999"));
        let _129_x129;
        _129_x129 = (_128_x128).multipliedBy(new BigNumber("9999999999999999999"));
        let _130_x130;
        _130_x130 = (_129_x129).multipliedBy(new BigNumber("9999999999999999999"));
        let _131_x131;
        _131_x131 = (_130_x130).multipliedBy(new BigNumber("9999999999999999999"));
        let _132_x132;
        _132_x132 = (_131_x131).multipliedBy(new BigNumber("9999999999999999999"));
        let _133_x133;
        _133_x133 = (_132_x132).multipliedBy(new BigNumber("9999999999999999999"));
        let _134_x134;
        _134_x134 = (_133_x133).multipliedBy(new BigNumber("9999999999999999999"));
        let _135_x135;
        _135_x135 = (_134_x134).multipliedBy(new BigNumber("9999999999999999999"));
        let _136_x136;
        _136_x136 = (_135_x135).multipliedBy(new BigNumber("9999999999999999999"));
        let _137_x137;
        _137_x137 = (_136_x136).multipliedBy(new BigNumber("9999999999999999999"));
        let _138_x138;
        _138_x138 = (_137_x137).multipliedBy(new BigNumber("9999999999999999999"));
        let _139_x139;
        _139_x139 = (_138_x138).multipliedBy(new BigNumber("9999999999999999999"));
        let _140_x140;
        _140_x140 = (_139_x139).multipliedBy(new BigNumber("9999999999999999999"));
        let _141_x141;
        _141_x141 = (_140_x140).multipliedBy(new BigNumber("9999999999999999999"));
        let _142_x142;
        _142_x142 = (_141_x141).multipliedBy(new BigNumber("9999999999999999999"));
        let _143_x143;
        _143_x143 = (_142_x142).multipliedBy(new BigNumber("9999999999999999999"));
        let _144_x144;
        _144_x144 = (_143_x143).multipliedBy(new BigNumber("9999999999999999999"));
        let _145_x145;
        _145_x145 = (_144_x144).multipliedBy(new BigNumber("9999999999999999999"));
        let _146_x146;
        _146_x146 = (_145_x145).multipliedBy(new BigNumber("9999999999999999999"));
        let _147_x147;
        _147_x147 = (_146_x146).multipliedBy(new BigNumber("9999999999999999999"));
        let _148_x148;
        _148_x148 = (_147_x147).multipliedBy(new BigNumber("9999999999999999999"));
        let _149_x149;
        _149_x149 = (_148_x148).multipliedBy(new BigNumber("9999999999999999999"));
        let _150_x150;
        _150_x150 = (_149_x149).multipliedBy(new BigNumber("9999999999999999999"));
        let _151_x151;
        _151_x151 = (_150_x150).multipliedBy(new BigNumber("9999999999999999999"));
        let _152_x152;
        _152_x152 = (_151_x151).multipliedBy(new BigNumber("9999999999999999999"));
        let _153_x153;
        _153_x153 = (_152_x152).multipliedBy(new BigNumber("9999999999999999999"));
        let _154_x154;
        _154_x154 = (_153_x153).multipliedBy(new BigNumber("9999999999999999999"));
        let _155_x155;
        _155_x155 = (_154_x154).multipliedBy(new BigNumber("9999999999999999999"));
        let _156_x156;
        _156_x156 = (_155_x155).multipliedBy(new BigNumber("9999999999999999999"));
        let _157_x157;
        _157_x157 = (_156_x156).multipliedBy(new BigNumber("9999999999999999999"));
        let _158_x158;
        _158_x158 = (_157_x157).multipliedBy(new BigNumber("9999999999999999999"));
        let _159_x159;
        _159_x159 = (_158_x158).multipliedBy(new BigNumber("9999999999999999999"));
        let _160_x160;
        _160_x160 = (_159_x159).multipliedBy(new BigNumber("9999999999999999999"));
        let _161_x161;
        _161_x161 = (_160_x160).multipliedBy(new BigNumber("9999999999999999999"));
        let _162_x162;
        _162_x162 = (_161_x161).multipliedBy(new BigNumber("9999999999999999999"));
        let _163_x163;
        _163_x163 = (_162_x162).multipliedBy(new BigNumber("9999999999999999999"));
        let _164_x164;
        _164_x164 = (_163_x163).multipliedBy(new BigNumber("9999999999999999999"));
        let _165_x165;
        _165_x165 = (_164_x164).multipliedBy(new BigNumber("9999999999999999999"));
        let _166_x166;
        _166_x166 = (_165_x165).multipliedBy(new BigNumber("9999999999999999999"));
        let _167_x167;
        _167_x167 = (_166_x166).multipliedBy(new BigNumber("9999999999999999999"));
        let _168_x168;
        _168_x168 = (_167_x167).multipliedBy(new BigNumber("9999999999999999999"));
        let _169_x169;
        _169_x169 = (_168_x168).multipliedBy(new BigNumber("9999999999999999999"));
        let _170_x170;
        _170_x170 = (_169_x169).multipliedBy(new BigNumber("9999999999999999999"));
        let _171_x171;
        _171_x171 = (_170_x170).multipliedBy(new BigNumber("9999999999999999999"));
        let _172_x172;
        _172_x172 = (_171_x171).multipliedBy(new BigNumber("9999999999999999999"));
        let _173_x173;
        _173_x173 = (_172_x172).multipliedBy(new BigNumber("9999999999999999999"));
        let _174_x174;
        _174_x174 = (_173_x173).multipliedBy(new BigNumber("9999999999999999999"));
        let _175_x175;
        _175_x175 = (_174_x174).multipliedBy(new BigNumber("9999999999999999999"));
        let _176_x176;
        _176_x176 = (_175_x175).multipliedBy(new BigNumber("9999999999999999999"));
        let _177_x177;
        _177_x177 = (_176_x176).multipliedBy(new BigNumber("9999999999999999999"));
        let _178_x178;
        _178_x178 = (_177_x177).multipliedBy(new BigNumber("9999999999999999999"));
        let _179_x179;
        _179_x179 = (_178_x178).multipliedBy(new BigNumber("9999999999999999999"));
        let _180_x180;
        _180_x180 = (_179_x179).multipliedBy(new BigNumber("9999999999999999999"));
        let _181_x181;
        _181_x181 = (_180_x180).multipliedBy(new BigNumber("9999999999999999999"));
        let _182_x182;
        _182_x182 = (_181_x181).multipliedBy(new BigNumber("9999999999999999999"));
        let _183_x183;
        _183_x183 = (_182_x182).multipliedBy(new BigNumber("9999999999999999999"));
        let _184_x184;
        _184_x184 = (_183_x183).multipliedBy(new BigNumber("9999999999999999999"));
        let _185_x185;
        _185_x185 = (_184_x184).multipliedBy(new BigNumber("9999999999999999999"));
        let _186_x186;
        _186_x186 = (_185_x185).multipliedBy(new BigNumber("9999999999999999999"));
        let _187_x187;
        _187_x187 = (_186_x186).multipliedBy(new BigNumber("9999999999999999999"));
        let _188_x188;
        _188_x188 = (_187_x187).multipliedBy(new BigNumber("9999999999999999999"));
        let _189_x189;
        _189_x189 = (_188_x188).multipliedBy(new BigNumber("9999999999999999999"));
        let _190_x190;
        _190_x190 = (_189_x189).multipliedBy(new BigNumber("9999999999999999999"));
        let _191_x191;
        _191_x191 = (_190_x190).multipliedBy(new BigNumber("9999999999999999999"));
        let _192_x192;
        _192_x192 = (_191_x191).multipliedBy(new BigNumber("9999999999999999999"));
        let _193_x193;
        _193_x193 = (_192_x192).multipliedBy(new BigNumber("9999999999999999999"));
        let _194_x194;
        _194_x194 = (_193_x193).multipliedBy(new BigNumber("9999999999999999999"));
        let _195_x195;
        _195_x195 = (_194_x194).multipliedBy(new BigNumber("9999999999999999999"));
        let _196_x196;
        _196_x196 = (_195_x195).multipliedBy(new BigNumber("9999999999999999999"));
        let _197_x197;
        _197_x197 = (_196_x196).multipliedBy(new BigNumber("9999999999999999999"));
        let _198_x198;
        _198_x198 = (_197_x197).multipliedBy(new BigNumber("9999999999999999999"));
        let _199_x199;
        _199_x199 = (_198_x198).multipliedBy(new BigNumber("9999999999999999999"));
        let _200_x200;
        _200_x200 = (_199_x199).multipliedBy(new BigNumber("9999999999999999999"));
        let _201_x201;
        _201_x201 = (_200_x200).multipliedBy(new BigNumber("9999999999999999999"));
        let _202_x202;
        _202_x202 = (_201_x201).multipliedBy(new BigNumber("9999999999999999999"));
        let _203_x203;
        _203_x203 = (_202_x202).multipliedBy(new BigNumber("9999999999999999999"));
        let _204_x204;
        _204_x204 = (_203_x203).multipliedBy(new BigNumber("9999999999999999999"));
        let _205_x205;
        _205_x205 = (_204_x204).multipliedBy(new BigNumber("9999999999999999999"));
        let _206_x206;
        _206_x206 = (_205_x205).multipliedBy(new BigNumber("9999999999999999999"));
        let _207_x207;
        _207_x207 = (_206_x206).multipliedBy(new BigNumber("9999999999999999999"));
        let _208_x208;
        _208_x208 = (_207_x207).multipliedBy(new BigNumber("9999999999999999999"));
        let _209_x209;
        _209_x209 = (_208_x208).multipliedBy(new BigNumber("9999999999999999999"));
        let _210_x210;
        _210_x210 = (_209_x209).multipliedBy(new BigNumber("9999999999999999999"));
        let _211_x211;
        _211_x211 = (_210_x210).multipliedBy(new BigNumber("9999999999999999999"));
        let _212_x212;
        _212_x212 = (_211_x211).multipliedBy(new BigNumber("9999999999999999999"));
        let _213_x213;
        _213_x213 = (_212_x212).multipliedBy(new BigNumber("9999999999999999999"));
        let _214_x214;
        _214_x214 = (_213_x213).multipliedBy(new BigNumber("9999999999999999999"));
        let _215_x215;
        _215_x215 = (_214_x214).multipliedBy(new BigNumber("9999999999999999999"));
        let _216_x216;
        _216_x216 = (_215_x215).multipliedBy(new BigNumber("9999999999999999999"));
        let _217_x217;
        _217_x217 = (_216_x216).multipliedBy(new BigNumber("9999999999999999999"));
        let _218_x218;
        _218_x218 = (_217_x217).multipliedBy(new BigNumber("9999999999999999999"));
        let _219_x219;
        _219_x219 = (_218_x218).multipliedBy(new BigNumber("9999999999999999999"));
        let _220_x220;
        _220_x220 = (_219_x219).multipliedBy(new BigNumber("9999999999999999999"));
        let _221_x221;
        _221_x221 = (_220_x220).multipliedBy(new BigNumber("9999999999999999999"));
        let _222_x222;
        _222_x222 = (_221_x221).multipliedBy(new BigNumber("9999999999999999999"));
        let _223_x223;
        _223_x223 = (_222_x222).multipliedBy(new BigNumber("9999999999999999999"));
        let _224_x224;
        _224_x224 = (_223_x223).multipliedBy(new BigNumber("9999999999999999999"));
        let _225_x225;
        _225_x225 = (_224_x224).multipliedBy(new BigNumber("9999999999999999999"));
        let _226_x226;
        _226_x226 = (_225_x225).multipliedBy(new BigNumber("9999999999999999999"));
        let _227_x227;
        _227_x227 = (_226_x226).multipliedBy(new BigNumber("9999999999999999999"));
        let _228_x228;
        _228_x228 = (_227_x227).multipliedBy(new BigNumber("9999999999999999999"));
        let _229_x229;
        _229_x229 = (_228_x228).multipliedBy(new BigNumber("9999999999999999999"));
        let _230_x230;
        _230_x230 = (_229_x229).multipliedBy(new BigNumber("9999999999999999999"));
        let _231_x231;
        _231_x231 = (_230_x230).multipliedBy(new BigNumber("9999999999999999999"));
        let _232_x232;
        _232_x232 = (_231_x231).multipliedBy(new BigNumber("9999999999999999999"));
        let _233_x233;
        _233_x233 = (_232_x232).multipliedBy(new BigNumber("9999999999999999999"));
        let _234_x234;
        _234_x234 = (_233_x233).multipliedBy(new BigNumber("9999999999999999999"));
        let _235_x235;
        _235_x235 = (_234_x234).multipliedBy(new BigNumber("9999999999999999999"));
        let _236_x236;
        _236_x236 = (_235_x235).multipliedBy(new BigNumber("9999999999999999999"));
        let _237_x237;
        _237_x237 = (_236_x236).multipliedBy(new BigNumber("9999999999999999999"));
        let _238_x238;
        _238_x238 = (_237_x237).multipliedBy(new BigNumber("9999999999999999999"));
        let _239_x239;
        _239_x239 = (_238_x238).multipliedBy(new BigNumber("9999999999999999999"));
        let _240_x240;
        _240_x240 = (_239_x239).multipliedBy(new BigNumber("9999999999999999999"));
        let _241_x241;
        _241_x241 = (_240_x240).multipliedBy(new BigNumber("9999999999999999999"));
        let _242_x242;
        _242_x242 = (_241_x241).multipliedBy(new BigNumber("9999999999999999999"));
        let _243_x243;
        _243_x243 = (_242_x242).multipliedBy(new BigNumber("9999999999999999999"));
        let _244_x244;
        _244_x244 = (_243_x243).multipliedBy(new BigNumber("9999999999999999999"));
        let _245_x245;
        _245_x245 = (_244_x244).multipliedBy(new BigNumber("9999999999999999999"));
        let _246_x246;
        _246_x246 = (_245_x245).multipliedBy(new BigNumber("9999999999999999999"));
        let _247_x247;
        _247_x247 = (_246_x246).multipliedBy(new BigNumber("9999999999999999999"));
        let _248_x248;
        _248_x248 = (_247_x247).multipliedBy(new BigNumber("9999999999999999999"));
        let _249_x249;
        _249_x249 = (_248_x248).multipliedBy(new BigNumber("9999999999999999999"));
        let _250_x250;
        _250_x250 = (_249_x249).multipliedBy(new BigNumber("9999999999999999999"));
        let _251_x251;
        _251_x251 = (_250_x250).multipliedBy(new BigNumber("9999999999999999999"));
        let _252_x252;
        _252_x252 = (_251_x251).multipliedBy(new BigNumber("9999999999999999999"));
        let _253_x253;
        _253_x253 = (_252_x252).multipliedBy(new BigNumber("9999999999999999999"));
        let _254_x254;
        _254_x254 = (_253_x253).multipliedBy(new BigNumber("9999999999999999999"));
        let _255_x255;
        _255_x255 = (_254_x254).multipliedBy(new BigNumber("9999999999999999999"));
        let _256_x256;
        _256_x256 = (_255_x255).multipliedBy(new BigNumber("9999999999999999999"));
        let _257_x257;
        _257_x257 = (_256_x256).multipliedBy(new BigNumber("9999999999999999999"));
        let _258_x258;
        _258_x258 = (_257_x257).multipliedBy(new BigNumber("9999999999999999999"));
        let _259_x259;
        _259_x259 = (_258_x258).multipliedBy(new BigNumber("9999999999999999999"));
        let _260_x260;
        _260_x260 = (_259_x259).multipliedBy(new BigNumber("9999999999999999999"));
        let _261_x261;
        _261_x261 = (_260_x260).multipliedBy(new BigNumber("9999999999999999999"));
        let _262_x262;
        _262_x262 = (_261_x261).multipliedBy(new BigNumber("9999999999999999999"));
        let _263_x263;
        _263_x263 = (_262_x262).multipliedBy(new BigNumber("9999999999999999999"));
        let _264_x264;
        _264_x264 = (_263_x263).multipliedBy(new BigNumber("9999999999999999999"));
        let _265_x265;
        _265_x265 = (_264_x264).multipliedBy(new BigNumber("9999999999999999999"));
        let _266_x266;
        _266_x266 = (_265_x265).multipliedBy(new BigNumber("9999999999999999999"));
        let _267_x267;
        _267_x267 = (_266_x266).multipliedBy(new BigNumber("9999999999999999999"));
        let _268_x268;
        _268_x268 = (_267_x267).multipliedBy(new BigNumber("9999999999999999999"));
        let _269_x269;
        _269_x269 = (_268_x268).multipliedBy(new BigNumber("9999999999999999999"));
        let _270_x270;
        _270_x270 = (_269_x269).multipliedBy(new BigNumber("9999999999999999999"));
        let _271_x271;
        _271_x271 = (_270_x270).multipliedBy(new BigNumber("9999999999999999999"));
        let _272_x272;
        _272_x272 = (_271_x271).multipliedBy(new BigNumber("9999999999999999999"));
        let _273_x273;
        _273_x273 = (_272_x272).multipliedBy(new BigNumber("9999999999999999999"));
        let _274_x274;
        _274_x274 = (_273_x273).multipliedBy(new BigNumber("9999999999999999999"));
        let _275_x275;
        _275_x275 = (_274_x274).multipliedBy(new BigNumber("9999999999999999999"));
        let _276_x276;
        _276_x276 = (_275_x275).multipliedBy(new BigNumber("9999999999999999999"));
        let _277_x277;
        _277_x277 = (_276_x276).multipliedBy(new BigNumber("9999999999999999999"));
        let _278_x278;
        _278_x278 = (_277_x277).multipliedBy(new BigNumber("9999999999999999999"));
        let _279_x279;
        _279_x279 = (_278_x278).multipliedBy(new BigNumber("9999999999999999999"));
        let _280_x280;
        _280_x280 = (_279_x279).multipliedBy(new BigNumber("9999999999999999999"));
        let _281_x281;
        _281_x281 = (_280_x280).multipliedBy(new BigNumber("9999999999999999999"));
        let _282_x282;
        _282_x282 = (_281_x281).multipliedBy(new BigNumber("9999999999999999999"));
        let _283_x283;
        _283_x283 = (_282_x282).multipliedBy(new BigNumber("9999999999999999999"));
        let _284_x284;
        _284_x284 = (_283_x283).multipliedBy(new BigNumber("9999999999999999999"));
        let _285_x285;
        _285_x285 = (_284_x284).multipliedBy(new BigNumber("9999999999999999999"));
        let _286_x286;
        _286_x286 = (_285_x285).multipliedBy(new BigNumber("9999999999999999999"));
        let _287_x287;
        _287_x287 = (_286_x286).multipliedBy(new BigNumber("9999999999999999999"));
        let _288_x288;
        _288_x288 = (_287_x287).multipliedBy(new BigNumber("9999999999999999999"));
        let _289_x289;
        _289_x289 = (_288_x288).multipliedBy(new BigNumber("9999999999999999999"));
        let _290_x290;
        _290_x290 = (_289_x289).multipliedBy(new BigNumber("9999999999999999999"));
        let _291_x291;
        _291_x291 = (_290_x290).multipliedBy(new BigNumber("9999999999999999999"));
        let _292_x292;
        _292_x292 = (_291_x291).multipliedBy(new BigNumber("9999999999999999999"));
        let _293_x293;
        _293_x293 = (_292_x292).multipliedBy(new BigNumber("9999999999999999999"));
        let _294_x294;
        _294_x294 = (_293_x293).multipliedBy(new BigNumber("9999999999999999999"));
        let _295_x295;
        _295_x295 = (_294_x294).multipliedBy(new BigNumber("9999999999999999999"));
        let _296_x296;
        _296_x296 = (_295_x295).multipliedBy(new BigNumber("9999999999999999999"));
        let _297_x297;
        _297_x297 = (_296_x296).multipliedBy(new BigNumber("9999999999999999999"));
        let _298_x298;
        _298_x298 = (_297_x297).multipliedBy(new BigNumber("9999999999999999999"));
        let _299_x299;
        _299_x299 = (_298_x298).multipliedBy(new BigNumber("9999999999999999999"));
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
