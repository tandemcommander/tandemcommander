# Data model - 409

- **Hint row** (`.slt` DIALOG section `D<n>`, row of control 102): `102,x,y,cx,cy,state,"text"`.
  Invariant after the feature: `x + cx` equals the English right edge of HEAD; `cx` = 84
  (D2350: 120) in English and in every enabled language; the text width in the dialog font
  `<= px(cx)`.
- **Pin** (`translations/ui-overrides.json`, `salamand.<language>`): key `#mask hints` or
  `#extended mask hints`, value the language's text; note list `_feature_409` in `salamand`.
