# override several font-family with my favorite fonts

FONT_TO_OVERRIDE = [
  "メイリオ",
  "Meiryo",
  "Meiryo UI",
  "游ゴシック",
  "MS Pゴシック",
  "MS PGothic",
  "MS ゴシック",
  "MS Gothic",
  "MS UI Gothic",
  "Open Sans",
  "ＭＳ Ｐゴシック",
  "Hiragino Sans",
  "Hiragino Kaku Gothic Pro",
  "Hiragino Maru Gothic Pro",
]
VF = %w(Noto-Sans-JP)
SRC = [
  'NotoSansJP',
  'NotoSansCJKjp',
]
WEIGHTS = {
  'Thin' => 100,
  'ExtraLight' => 200,
  'Light' => 300,
  'Regular' => 400,
  'Medium' => 500,
  'SemiBold' => 600,
  'Bold' => 700,
  'ExtraBold' => 800,
  'Black' => 900,
}

FONT_TO_OVERRIDE.each do |font_spec|
  WEIGHTS.each do |psname, weight|
    locals = [*VF, *SRC.map { |local| "#{local}-#{psname}" }]
    puts <<~EOF
      @font-face {
          font-family: "#{font_spec}";
          font-weight: #{weight};
          src: #{locals.map { |local| %|local("#{local}")| }.join(', ')}
      }
    EOF
  end
  locals = [*VF, *SRC.map { |local| "#{local}-Regular" }]
  puts <<~EOF
    @font-face {
        font-family: "#{font_spec}";
        src: #{locals.map { |local| %|local("#{local}")| }.join(', ')}
    }
  EOF
end

puts <<~EOF
@font-face {
    font-family: "Segoe UI";
    font-weight: 400;
    font-style: normal;
   src: local("Noto-Sans-JP"), local("NotoSansJP-Regular"), local("NotoSansCJKjp-Regular"), local("SourceHanSans-Regular"), local("Noto Sans CJK JP"), local("BIZ-UDPGothic"), local("YuGothic-Medium");
    unicode-range: U+30??, U+3400-4DB5, U+4E00-9FCB, U+F900-FA6A, U+2E80-2FD5, U+FF5F-FF9F, U+31F0-31FF, U+3220-3243, U+3280-337F, U+FF01-FF5E;
}

@font-face {
    font-family: "Segoe UI";
    font-weight: 200;
    font-style: normal;
    src:  local("SegoeUI-Light"), local("SourceHanSans-Light"), local("Noto-Sans-JP"), local("NotoSansJP-Light"), local("NotoSansCJKjp-Light");
}
@font-face {
    font-family: "Segoe UI";
    font-weight: 300;
    font-style: normal;
    src:  local("SegoeUI-Semilight"), local("SourceHanSans-Semilight"), local("Noto-Sans-JP"), local("NotoSansJP-Medium"), local("NotoSansCJKjp-Medium");
}
@font-face {
    font-family: "Segoe UI";
    font-weight: 400;
    font-style: normal;
    src:  local("SegoeUI"), local("SourceHanSans-Regular"), local("Noto-Sans-JP"), local("NotoSansJP-Regular"), local("NotoSansCJKjp-Regular");
}
@font-face {
    font-family: "Segoe UI";
    font-weight: 600;
    font-style: normal;
    src:  local("SegoeUI-Semibold"), local("SourceHanSans-SemiBold"), local("Noto-Sans-JP"), local("NotoSansJP-SemiBold"), local("NotoSansCJKjp-SemiBold");
}
@font-face {
    font-family: "Segoe UI";
    font-weight: 700;
    font-style: normal;
    src:  local("SegoeUI-Bold"), local("SourceHanSans-Bold"),local("Noto-Sans-JP"),  local("NotoSansJP-Bold"), local("NotoSansCJKjp-Bold");;
}

@font-face {
    font-family: "Segoe UI";
    font-weight: 200;
    font-style: italic;
    src:  local("SegoeUI-LightItalic"), local("SourceHanSans-Light"), local("Noto-Sans-JP"), local("NotoSansJP-Light"), local("NotoSansCJKjp-Light");
}
@font-face {
    font-family: "Segoe UI";
    font-weight: 300;
    font-style: italic;
    src:  local("SegoeUI-SemilightItalic"), local("SourceHanSans-Semilight"), local("Noto-Sans-JP"), local("NotoSansJP-Medium"), local("NotoSansCJKjp-Medium");
}
@font-face {
    font-family: "Segoe UI";
    font-weight: 400;
    font-style: italic;
    src:  local("SegoeUI-Italic"), local("SourceHanSans-Regular"), local("Noto-Sans-JP"), local("NotoSansJP-Regular"), local("NotoSansCJKjp-Regular");
}
@font-face {
    font-family: "Segoe UI";
    font-weight: 600;
    font-style: italic;
    src:  local("SegoeUI-SemiboldItalic"), local("SourceHanSans-SemiBold"), local("Noto-Sans-JP"), local("NotoSansJP-SemiBold"), local("NotoSansCJKjp-SemiBold");
}
@font-face {
    font-family: "Segoe UI";
    font-weight: 700;
    font-style: italic;
    src:  local("SegoeUI-BoldItalic"), local("SourceHanSans-Bold"), local("Noto-Sans-JP"), local("NotoSansJP-Bold"), local("NotoSansCJKjp-Bold");;
}
EOF
