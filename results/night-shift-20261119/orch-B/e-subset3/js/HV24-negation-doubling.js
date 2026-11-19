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
        _1_x1 = (_0_x0).minus((_dafny.ZERO).minus(_0_x0));
        let _2_x2;
        _2_x2 = (_1_x1).minus((_dafny.ZERO).minus(_1_x1));
        let _3_x3;
        _3_x3 = (_2_x2).minus((_dafny.ZERO).minus(_2_x2));
        let _4_x4;
        _4_x4 = (_3_x3).minus((_dafny.ZERO).minus(_3_x3));
        let _5_x5;
        _5_x5 = (_4_x4).minus((_dafny.ZERO).minus(_4_x4));
        let _6_x6;
        _6_x6 = (_5_x5).minus((_dafny.ZERO).minus(_5_x5));
        let _7_x7;
        _7_x7 = (_6_x6).minus((_dafny.ZERO).minus(_6_x6));
        let _8_x8;
        _8_x8 = (_7_x7).minus((_dafny.ZERO).minus(_7_x7));
        let _9_x9;
        _9_x9 = (_8_x8).minus((_dafny.ZERO).minus(_8_x8));
        let _10_x10;
        _10_x10 = (_9_x9).minus((_dafny.ZERO).minus(_9_x9));
        let _11_x11;
        _11_x11 = (_10_x10).minus((_dafny.ZERO).minus(_10_x10));
        let _12_x12;
        _12_x12 = (_11_x11).minus((_dafny.ZERO).minus(_11_x11));
        let _13_x13;
        _13_x13 = (_12_x12).minus((_dafny.ZERO).minus(_12_x12));
        let _14_x14;
        _14_x14 = (_13_x13).minus((_dafny.ZERO).minus(_13_x13));
        let _15_x15;
        _15_x15 = (_14_x14).minus((_dafny.ZERO).minus(_14_x14));
        let _16_x16;
        _16_x16 = (_15_x15).minus((_dafny.ZERO).minus(_15_x15));
        let _17_x17;
        _17_x17 = (_16_x16).minus((_dafny.ZERO).minus(_16_x16));
        let _18_x18;
        _18_x18 = (_17_x17).minus((_dafny.ZERO).minus(_17_x17));
        let _19_x19;
        _19_x19 = (_18_x18).minus((_dafny.ZERO).minus(_18_x18));
        let _20_x20;
        _20_x20 = (_19_x19).minus((_dafny.ZERO).minus(_19_x19));
        let _21_x21;
        _21_x21 = (_20_x20).minus((_dafny.ZERO).minus(_20_x20));
        let _22_x22;
        _22_x22 = (_21_x21).minus((_dafny.ZERO).minus(_21_x21));
        let _23_x23;
        _23_x23 = (_22_x22).minus((_dafny.ZERO).minus(_22_x22));
        let _24_x24;
        _24_x24 = (_23_x23).minus((_dafny.ZERO).minus(_23_x23));
        let _25_x25;
        _25_x25 = (_24_x24).minus((_dafny.ZERO).minus(_24_x24));
        let _26_x26;
        _26_x26 = (_25_x25).minus((_dafny.ZERO).minus(_25_x25));
        let _27_x27;
        _27_x27 = (_26_x26).minus((_dafny.ZERO).minus(_26_x26));
        let _28_x28;
        _28_x28 = (_27_x27).minus((_dafny.ZERO).minus(_27_x27));
        let _29_x29;
        _29_x29 = (_28_x28).minus((_dafny.ZERO).minus(_28_x28));
        let _30_x30;
        _30_x30 = (_29_x29).minus((_dafny.ZERO).minus(_29_x29));
        let _31_x31;
        _31_x31 = (_30_x30).minus((_dafny.ZERO).minus(_30_x30));
        let _32_x32;
        _32_x32 = (_31_x31).minus((_dafny.ZERO).minus(_31_x31));
        let _33_x33;
        _33_x33 = (_32_x32).minus((_dafny.ZERO).minus(_32_x32));
        let _34_x34;
        _34_x34 = (_33_x33).minus((_dafny.ZERO).minus(_33_x33));
        let _35_x35;
        _35_x35 = (_34_x34).minus((_dafny.ZERO).minus(_34_x34));
        let _36_x36;
        _36_x36 = (_35_x35).minus((_dafny.ZERO).minus(_35_x35));
        let _37_x37;
        _37_x37 = (_36_x36).minus((_dafny.ZERO).minus(_36_x36));
        let _38_x38;
        _38_x38 = (_37_x37).minus((_dafny.ZERO).minus(_37_x37));
        let _39_x39;
        _39_x39 = (_38_x38).minus((_dafny.ZERO).minus(_38_x38));
        let _40_x40;
        _40_x40 = (_39_x39).minus((_dafny.ZERO).minus(_39_x39));
        let _41_x41;
        _41_x41 = (_40_x40).minus((_dafny.ZERO).minus(_40_x40));
        let _42_x42;
        _42_x42 = (_41_x41).minus((_dafny.ZERO).minus(_41_x41));
        let _43_x43;
        _43_x43 = (_42_x42).minus((_dafny.ZERO).minus(_42_x42));
        let _44_x44;
        _44_x44 = (_43_x43).minus((_dafny.ZERO).minus(_43_x43));
        let _45_x45;
        _45_x45 = (_44_x44).minus((_dafny.ZERO).minus(_44_x44));
        let _46_x46;
        _46_x46 = (_45_x45).minus((_dafny.ZERO).minus(_45_x45));
        let _47_x47;
        _47_x47 = (_46_x46).minus((_dafny.ZERO).minus(_46_x46));
        let _48_x48;
        _48_x48 = (_47_x47).minus((_dafny.ZERO).minus(_47_x47));
        let _49_x49;
        _49_x49 = (_48_x48).minus((_dafny.ZERO).minus(_48_x48));
        let _50_x50;
        _50_x50 = (_49_x49).minus((_dafny.ZERO).minus(_49_x49));
        let _51_x51;
        _51_x51 = (_50_x50).minus((_dafny.ZERO).minus(_50_x50));
        let _52_x52;
        _52_x52 = (_51_x51).minus((_dafny.ZERO).minus(_51_x51));
        let _53_x53;
        _53_x53 = (_52_x52).minus((_dafny.ZERO).minus(_52_x52));
        let _54_x54;
        _54_x54 = (_53_x53).minus((_dafny.ZERO).minus(_53_x53));
        let _55_x55;
        _55_x55 = (_54_x54).minus((_dafny.ZERO).minus(_54_x54));
        let _56_x56;
        _56_x56 = (_55_x55).minus((_dafny.ZERO).minus(_55_x55));
        let _57_x57;
        _57_x57 = (_56_x56).minus((_dafny.ZERO).minus(_56_x56));
        let _58_x58;
        _58_x58 = (_57_x57).minus((_dafny.ZERO).minus(_57_x57));
        let _59_x59;
        _59_x59 = (_58_x58).minus((_dafny.ZERO).minus(_58_x58));
        let _60_x60;
        _60_x60 = (_59_x59).minus((_dafny.ZERO).minus(_59_x59));
        let _61_x61;
        _61_x61 = (_60_x60).minus((_dafny.ZERO).minus(_60_x60));
        let _62_x62;
        _62_x62 = (_61_x61).minus((_dafny.ZERO).minus(_61_x61));
        let _63_x63;
        _63_x63 = (_62_x62).minus((_dafny.ZERO).minus(_62_x62));
        let _64_x64;
        _64_x64 = (_63_x63).minus((_dafny.ZERO).minus(_63_x63));
        let _65_x65;
        _65_x65 = (_64_x64).minus((_dafny.ZERO).minus(_64_x64));
        let _66_x66;
        _66_x66 = (_65_x65).minus((_dafny.ZERO).minus(_65_x65));
        let _67_x67;
        _67_x67 = (_66_x66).minus((_dafny.ZERO).minus(_66_x66));
        let _68_x68;
        _68_x68 = (_67_x67).minus((_dafny.ZERO).minus(_67_x67));
        let _69_x69;
        _69_x69 = (_68_x68).minus((_dafny.ZERO).minus(_68_x68));
        let _70_x70;
        _70_x70 = (_69_x69).minus((_dafny.ZERO).minus(_69_x69));
        let _71_x71;
        _71_x71 = (_70_x70).minus((_dafny.ZERO).minus(_70_x70));
        let _72_x72;
        _72_x72 = (_71_x71).minus((_dafny.ZERO).minus(_71_x71));
        let _73_x73;
        _73_x73 = (_72_x72).minus((_dafny.ZERO).minus(_72_x72));
        let _74_x74;
        _74_x74 = (_73_x73).minus((_dafny.ZERO).minus(_73_x73));
        let _75_x75;
        _75_x75 = (_74_x74).minus((_dafny.ZERO).minus(_74_x74));
        let _76_x76;
        _76_x76 = (_75_x75).minus((_dafny.ZERO).minus(_75_x75));
        let _77_x77;
        _77_x77 = (_76_x76).minus((_dafny.ZERO).minus(_76_x76));
        let _78_x78;
        _78_x78 = (_77_x77).minus((_dafny.ZERO).minus(_77_x77));
        let _79_x79;
        _79_x79 = (_78_x78).minus((_dafny.ZERO).minus(_78_x78));
        let _80_x80;
        _80_x80 = (_79_x79).minus((_dafny.ZERO).minus(_79_x79));
        let _81_x81;
        _81_x81 = (_80_x80).minus((_dafny.ZERO).minus(_80_x80));
        let _82_x82;
        _82_x82 = (_81_x81).minus((_dafny.ZERO).minus(_81_x81));
        let _83_x83;
        _83_x83 = (_82_x82).minus((_dafny.ZERO).minus(_82_x82));
        let _84_x84;
        _84_x84 = (_83_x83).minus((_dafny.ZERO).minus(_83_x83));
        let _85_x85;
        _85_x85 = (_84_x84).minus((_dafny.ZERO).minus(_84_x84));
        let _86_x86;
        _86_x86 = (_85_x85).minus((_dafny.ZERO).minus(_85_x85));
        let _87_x87;
        _87_x87 = (_86_x86).minus((_dafny.ZERO).minus(_86_x86));
        let _88_x88;
        _88_x88 = (_87_x87).minus((_dafny.ZERO).minus(_87_x87));
        let _89_x89;
        _89_x89 = (_88_x88).minus((_dafny.ZERO).minus(_88_x88));
        let _90_x90;
        _90_x90 = (_89_x89).minus((_dafny.ZERO).minus(_89_x89));
        let _91_x91;
        _91_x91 = (_90_x90).minus((_dafny.ZERO).minus(_90_x90));
        let _92_x92;
        _92_x92 = (_91_x91).minus((_dafny.ZERO).minus(_91_x91));
        let _93_x93;
        _93_x93 = (_92_x92).minus((_dafny.ZERO).minus(_92_x92));
        let _94_x94;
        _94_x94 = (_93_x93).minus((_dafny.ZERO).minus(_93_x93));
        let _95_x95;
        _95_x95 = (_94_x94).minus((_dafny.ZERO).minus(_94_x94));
        let _96_x96;
        _96_x96 = (_95_x95).minus((_dafny.ZERO).minus(_95_x95));
        let _97_x97;
        _97_x97 = (_96_x96).minus((_dafny.ZERO).minus(_96_x96));
        let _98_x98;
        _98_x98 = (_97_x97).minus((_dafny.ZERO).minus(_97_x97));
        let _99_x99;
        _99_x99 = (_98_x98).minus((_dafny.ZERO).minus(_98_x98));
        let _100_x100;
        _100_x100 = (_99_x99).minus((_dafny.ZERO).minus(_99_x99));
        let _101_x101;
        _101_x101 = (_100_x100).minus((_dafny.ZERO).minus(_100_x100));
        let _102_x102;
        _102_x102 = (_101_x101).minus((_dafny.ZERO).minus(_101_x101));
        let _103_x103;
        _103_x103 = (_102_x102).minus((_dafny.ZERO).minus(_102_x102));
        let _104_x104;
        _104_x104 = (_103_x103).minus((_dafny.ZERO).minus(_103_x103));
        let _105_x105;
        _105_x105 = (_104_x104).minus((_dafny.ZERO).minus(_104_x104));
        let _106_x106;
        _106_x106 = (_105_x105).minus((_dafny.ZERO).minus(_105_x105));
        let _107_x107;
        _107_x107 = (_106_x106).minus((_dafny.ZERO).minus(_106_x106));
        let _108_x108;
        _108_x108 = (_107_x107).minus((_dafny.ZERO).minus(_107_x107));
        let _109_x109;
        _109_x109 = (_108_x108).minus((_dafny.ZERO).minus(_108_x108));
        let _110_x110;
        _110_x110 = (_109_x109).minus((_dafny.ZERO).minus(_109_x109));
        let _111_x111;
        _111_x111 = (_110_x110).minus((_dafny.ZERO).minus(_110_x110));
        let _112_x112;
        _112_x112 = (_111_x111).minus((_dafny.ZERO).minus(_111_x111));
        let _113_x113;
        _113_x113 = (_112_x112).minus((_dafny.ZERO).minus(_112_x112));
        let _114_x114;
        _114_x114 = (_113_x113).minus((_dafny.ZERO).minus(_113_x113));
        let _115_x115;
        _115_x115 = (_114_x114).minus((_dafny.ZERO).minus(_114_x114));
        let _116_x116;
        _116_x116 = (_115_x115).minus((_dafny.ZERO).minus(_115_x115));
        let _117_x117;
        _117_x117 = (_116_x116).minus((_dafny.ZERO).minus(_116_x116));
        let _118_x118;
        _118_x118 = (_117_x117).minus((_dafny.ZERO).minus(_117_x117));
        let _119_x119;
        _119_x119 = (_118_x118).minus((_dafny.ZERO).minus(_118_x118));
        let _120_x120;
        _120_x120 = (_119_x119).minus((_dafny.ZERO).minus(_119_x119));
        let _121_x121;
        _121_x121 = (_120_x120).minus((_dafny.ZERO).minus(_120_x120));
        let _122_x122;
        _122_x122 = (_121_x121).minus((_dafny.ZERO).minus(_121_x121));
        let _123_x123;
        _123_x123 = (_122_x122).minus((_dafny.ZERO).minus(_122_x122));
        let _124_x124;
        _124_x124 = (_123_x123).minus((_dafny.ZERO).minus(_123_x123));
        let _125_x125;
        _125_x125 = (_124_x124).minus((_dafny.ZERO).minus(_124_x124));
        let _126_x126;
        _126_x126 = (_125_x125).minus((_dafny.ZERO).minus(_125_x125));
        let _127_x127;
        _127_x127 = (_126_x126).minus((_dafny.ZERO).minus(_126_x126));
        let _128_x128;
        _128_x128 = (_127_x127).minus((_dafny.ZERO).minus(_127_x127));
        let _129_x129;
        _129_x129 = (_128_x128).minus((_dafny.ZERO).minus(_128_x128));
        let _130_x130;
        _130_x130 = (_129_x129).minus((_dafny.ZERO).minus(_129_x129));
        let _131_x131;
        _131_x131 = (_130_x130).minus((_dafny.ZERO).minus(_130_x130));
        let _132_x132;
        _132_x132 = (_131_x131).minus((_dafny.ZERO).minus(_131_x131));
        let _133_x133;
        _133_x133 = (_132_x132).minus((_dafny.ZERO).minus(_132_x132));
        let _134_x134;
        _134_x134 = (_133_x133).minus((_dafny.ZERO).minus(_133_x133));
        let _135_x135;
        _135_x135 = (_134_x134).minus((_dafny.ZERO).minus(_134_x134));
        let _136_x136;
        _136_x136 = (_135_x135).minus((_dafny.ZERO).minus(_135_x135));
        let _137_x137;
        _137_x137 = (_136_x136).minus((_dafny.ZERO).minus(_136_x136));
        let _138_x138;
        _138_x138 = (_137_x137).minus((_dafny.ZERO).minus(_137_x137));
        let _139_x139;
        _139_x139 = (_138_x138).minus((_dafny.ZERO).minus(_138_x138));
        let _140_x140;
        _140_x140 = (_139_x139).minus((_dafny.ZERO).minus(_139_x139));
        let _141_x141;
        _141_x141 = (_140_x140).minus((_dafny.ZERO).minus(_140_x140));
        let _142_x142;
        _142_x142 = (_141_x141).minus((_dafny.ZERO).minus(_141_x141));
        let _143_x143;
        _143_x143 = (_142_x142).minus((_dafny.ZERO).minus(_142_x142));
        let _144_x144;
        _144_x144 = (_143_x143).minus((_dafny.ZERO).minus(_143_x143));
        let _145_x145;
        _145_x145 = (_144_x144).minus((_dafny.ZERO).minus(_144_x144));
        let _146_x146;
        _146_x146 = (_145_x145).minus((_dafny.ZERO).minus(_145_x145));
        let _147_x147;
        _147_x147 = (_146_x146).minus((_dafny.ZERO).minus(_146_x146));
        let _148_x148;
        _148_x148 = (_147_x147).minus((_dafny.ZERO).minus(_147_x147));
        let _149_x149;
        _149_x149 = (_148_x148).minus((_dafny.ZERO).minus(_148_x148));
        let _150_x150;
        _150_x150 = (_149_x149).minus((_dafny.ZERO).minus(_149_x149));
        let _151_x151;
        _151_x151 = (_150_x150).minus((_dafny.ZERO).minus(_150_x150));
        let _152_x152;
        _152_x152 = (_151_x151).minus((_dafny.ZERO).minus(_151_x151));
        let _153_x153;
        _153_x153 = (_152_x152).minus((_dafny.ZERO).minus(_152_x152));
        let _154_x154;
        _154_x154 = (_153_x153).minus((_dafny.ZERO).minus(_153_x153));
        let _155_x155;
        _155_x155 = (_154_x154).minus((_dafny.ZERO).minus(_154_x154));
        let _156_x156;
        _156_x156 = (_155_x155).minus((_dafny.ZERO).minus(_155_x155));
        let _157_x157;
        _157_x157 = (_156_x156).minus((_dafny.ZERO).minus(_156_x156));
        let _158_x158;
        _158_x158 = (_157_x157).minus((_dafny.ZERO).minus(_157_x157));
        let _159_x159;
        _159_x159 = (_158_x158).minus((_dafny.ZERO).minus(_158_x158));
        let _160_x160;
        _160_x160 = (_159_x159).minus((_dafny.ZERO).minus(_159_x159));
        let _161_x161;
        _161_x161 = (_160_x160).minus((_dafny.ZERO).minus(_160_x160));
        let _162_x162;
        _162_x162 = (_161_x161).minus((_dafny.ZERO).minus(_161_x161));
        let _163_x163;
        _163_x163 = (_162_x162).minus((_dafny.ZERO).minus(_162_x162));
        let _164_x164;
        _164_x164 = (_163_x163).minus((_dafny.ZERO).minus(_163_x163));
        let _165_x165;
        _165_x165 = (_164_x164).minus((_dafny.ZERO).minus(_164_x164));
        let _166_x166;
        _166_x166 = (_165_x165).minus((_dafny.ZERO).minus(_165_x165));
        let _167_x167;
        _167_x167 = (_166_x166).minus((_dafny.ZERO).minus(_166_x166));
        let _168_x168;
        _168_x168 = (_167_x167).minus((_dafny.ZERO).minus(_167_x167));
        let _169_x169;
        _169_x169 = (_168_x168).minus((_dafny.ZERO).minus(_168_x168));
        let _170_x170;
        _170_x170 = (_169_x169).minus((_dafny.ZERO).minus(_169_x169));
        let _171_x171;
        _171_x171 = (_170_x170).minus((_dafny.ZERO).minus(_170_x170));
        let _172_x172;
        _172_x172 = (_171_x171).minus((_dafny.ZERO).minus(_171_x171));
        let _173_x173;
        _173_x173 = (_172_x172).minus((_dafny.ZERO).minus(_172_x172));
        let _174_x174;
        _174_x174 = (_173_x173).minus((_dafny.ZERO).minus(_173_x173));
        let _175_x175;
        _175_x175 = (_174_x174).minus((_dafny.ZERO).minus(_174_x174));
        let _176_x176;
        _176_x176 = (_175_x175).minus((_dafny.ZERO).minus(_175_x175));
        let _177_x177;
        _177_x177 = (_176_x176).minus((_dafny.ZERO).minus(_176_x176));
        let _178_x178;
        _178_x178 = (_177_x177).minus((_dafny.ZERO).minus(_177_x177));
        let _179_x179;
        _179_x179 = (_178_x178).minus((_dafny.ZERO).minus(_178_x178));
        let _180_x180;
        _180_x180 = (_179_x179).minus((_dafny.ZERO).minus(_179_x179));
        let _181_x181;
        _181_x181 = (_180_x180).minus((_dafny.ZERO).minus(_180_x180));
        let _182_x182;
        _182_x182 = (_181_x181).minus((_dafny.ZERO).minus(_181_x181));
        let _183_x183;
        _183_x183 = (_182_x182).minus((_dafny.ZERO).minus(_182_x182));
        let _184_x184;
        _184_x184 = (_183_x183).minus((_dafny.ZERO).minus(_183_x183));
        let _185_x185;
        _185_x185 = (_184_x184).minus((_dafny.ZERO).minus(_184_x184));
        let _186_x186;
        _186_x186 = (_185_x185).minus((_dafny.ZERO).minus(_185_x185));
        let _187_x187;
        _187_x187 = (_186_x186).minus((_dafny.ZERO).minus(_186_x186));
        let _188_x188;
        _188_x188 = (_187_x187).minus((_dafny.ZERO).minus(_187_x187));
        let _189_x189;
        _189_x189 = (_188_x188).minus((_dafny.ZERO).minus(_188_x188));
        let _190_x190;
        _190_x190 = (_189_x189).minus((_dafny.ZERO).minus(_189_x189));
        let _191_x191;
        _191_x191 = (_190_x190).minus((_dafny.ZERO).minus(_190_x190));
        let _192_x192;
        _192_x192 = (_191_x191).minus((_dafny.ZERO).minus(_191_x191));
        let _193_x193;
        _193_x193 = (_192_x192).minus((_dafny.ZERO).minus(_192_x192));
        let _194_x194;
        _194_x194 = (_193_x193).minus((_dafny.ZERO).minus(_193_x193));
        let _195_x195;
        _195_x195 = (_194_x194).minus((_dafny.ZERO).minus(_194_x194));
        let _196_x196;
        _196_x196 = (_195_x195).minus((_dafny.ZERO).minus(_195_x195));
        let _197_x197;
        _197_x197 = (_196_x196).minus((_dafny.ZERO).minus(_196_x196));
        let _198_x198;
        _198_x198 = (_197_x197).minus((_dafny.ZERO).minus(_197_x197));
        let _199_x199;
        _199_x199 = (_198_x198).minus((_dafny.ZERO).minus(_198_x198));
        let _200_x200;
        _200_x200 = (_199_x199).minus((_dafny.ZERO).minus(_199_x199));
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
