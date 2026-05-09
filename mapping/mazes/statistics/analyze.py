import os

text_file = open("torah.txt", "r", encoding="utf-8")
text = text_file.read()

letters_table = {
    ".": "00-BREAK",
	"א": "01-aleph",
	"ב": "02-bet",
	"ג": "03-gimel",
	"ד": "04-dalet",
	"ה": "05-he",
	"ו": "06-vav",
	"ז": "07-zayin",
	"ח": "08-chet",
	"ט": "09-tet",
	"י": "10-yod",
	"כ": "11-kaf",
	"ל": "12-lamed",
	"מ": "13-mem",
	"נ": "14-nun",
	"ס": "15-samekh",
	"ע": "16-ayin",
	"פ": "17-pe",
	"צ": "18-tsadi",
	"ק": "19-qof",
	"ר": "20-resh",
	"ש": "21-shin",
	"ת": "22-tav",
}

# replacing some variations of the letters
text = text.replace("ך", "כ")
text = text.replace("ם", "מ")
text = text.replace("ן", "נ")
text = text.replace("ף", "פ")
text = text.replace("ץ", "צ")

# normalizing text
text = list(text)
for index in range(len(text)):
	if not text[index] in letters_table:
		text[index] = "."

# preparing tables
letters = {}
for letter in letters_table:
	letters[letter] = {}
	for next_letter in letters_table:
		letters[letter][next_letter] = 0

# generating the table of next letters for each letter
for index in range(len(text) - 1):
	letter = text[index]
	next_letter = text[index + 1]
	letters[letter][next_letter] += 1

for letter in letters:
	count = 0
	for next_letter in letters[letter]:
		count += letters[letter][next_letter]
	if count == 0: continue
	for next_letter in letters[letter]:
		letters[letter][next_letter] /= count
		letters[letter][next_letter] *= 100.0

for letter in letters:
	letters[letter] = dict(sorted(letters[letter].items(),
		key=lambda item: item[1], reverse = True))

# printing statistics
print("{")
for letter in letters:
	if letter == ".": continue
	print(f'\t"rooms/{letters_table[letter]}": ' + "{")
	for next_letter in letters[letter]:
		print(f'\t\t"rooms/{letters_table[next_letter]}": {letters[letter][next_letter]:g},')
	print("\t},")
print("}")
