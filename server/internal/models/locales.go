package models

// accountLocales espelha LANGUAGES_CONFIG do Chatwoot (config/initializers/languages.rb). Os índices são
// gravados em accounts.locale e nunca mudam.
var accountLocales = map[int32]string{
	0:  "en",
	1:  "ar",
	2:  "nl",
	3:  "fr",
	4:  "de",
	5:  "hi",
	6:  "it",
	7:  "ja",
	8:  "ko",
	9:  "pt",
	10: "ru",
	11: "zh",
	12: "es",
	13: "ml",
	14: "ca",
	15: "el",
	16: "pt_BR",
	17: "ro",
	18: "ta",
	19: "fa",
	20: "zh_TW",
	21: "vi",
	22: "da",
	23: "tr",
	24: "cs",
	25: "fi",
	26: "id",
	27: "sv",
	28: "hu",
	29: "no",
	30: "zh_CN",
	31: "pl",
	32: "sk",
	33: "uk",
	34: "th",
	35: "lv",
	36: "is",
	37: "he",
	38: "lt",
	39: "sr",
	40: "bg",
	41: "et",
	42: "uz",
	43: "sl",
}

func localeCode(index int32) string {
	if code, ok := accountLocales[index]; ok {
		return code
	}
	return "en"
}
