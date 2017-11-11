#! /bin/bash
# This current script's version:
TUI_VER="Diatheke-TUI v1.0" 
# Diatheke is a terminal based bible software included with SWORD.
# This is a front-end that uses whiptail for a basic TUI.
# Depends: coreutils, libsword, libnewt 
# Opt-Depends: curl (downloading modules), unzip (installing modules), libcaca (image viewer)
# License: CC0

## Diatheke manpage notes #################
# https://www.huge-man-linux.net/man1/diatheke.html
# https://crosswire.org/wiki/Frontends:Diatheke
###################################

## TODO: Work around MHC commentary Psalms 119 limitation: "Argument list too long" in bash.
## http://www.linuxjournal.com/article/6060

## User Configurations #############################################
SWORD_DIR=$HOME/.sword # <-- Set SWORD directory here. (Or leave default)
MODULES_DIR=$SWORD_DIR/modules # Modules directory
BIBLE_MOD="" # <-- Set your default bible module here, else we try to set one for you.
DICT_MOD="" # <-- Set your default dictionary module here, else we try to set one for you.
COMMEN_MOD="" # <-- Set your default commentary module here, else we try to set one for you.
BOOK_MOD="" # <-- Set your default book module here, else we try to set one for you.
LOCALE="en" # <-- Set your LOCALE here.
MENUSELECT="4)" # <-- Set your default pre-selected Main Menu item.
#############################################################

## Test for SWORD directory, ask to create if doesn't exist.
if [ ! -d "$SWORD_DIR" ]; then
	if (whiptail --title "First Time Menu" --backtitle "$TUI_VER" --yes-button "Continue (Recommended)" --no-button "Skip (Won't work properly)"  --yesno "Welcome,\nThis appears to be your first time using $TUI_VER!\nPress Continue to have the .sword directory created in $HOME for you.\nOr manually set one within this script." 10 90) then
		mkdir -p "$SWORD_DIR";
	else
		echo "Error!: SWORD_DIR is not set! Cannot continue properly. Be sure to set one or Create it."
	fi
  
fi

## Query installed modules function
function getModules() {
	# Regex to get installed Bible modules
	BIBLES=$(diatheke -b system -k modulelist | sed -n '/^Biblical\ Texts:$/,/^Commentaries:$/p' | sed -e '1d;$d' -e 's/\s.*$//')
	# Regex to get installed Dictionary modules
	DICTIONARIES=$(diatheke -b system -k modulelist | sed -n '/^Dictionaries:$/,/^Generic\ books:$/p' | sed -e '1d;$d' -e 's/\s.*$//')
	## Regex to get installed Commentary modules
	COMMENTARIES=$(diatheke -b system -k modulelist | sed -n '/^Commentaries:$/,/^Dictionaries:$/p' | sed -e '1d;$d' -e 's/\s.*$//')
	## Regex to get installed Generic Book modules
	BOOKS=$(diatheke -b system -k modulelist | sed -n '/^Generic\ books:$/,$p' | sed -e '1d' -e 's/\s.*$//')
	## Find installed images/maps
	IMAGES=$(find ~/.sword -name '*.jpg' -o -name '*.bmp' -o -name '*.png' -o -name '*.gif' | sed 's#.*/##')
	## Regex to remove new lines: sed ':a;N;$!ba;s/\n/ /g'
}
############
getModules ## Call function


## Function that tries to set modules using installed ones even if none are set.
function setModules() {
	if [ -z "$BIBLE_MOD" ]; then
		BIBLE_MOD=$(head -n1 <<< "$BIBLES")
		if [ -z "$BIBLE_MOD" ]; then
		BIBLE_MOD="NONE"
		## Warn user about not having any Bible Module. Typically only appears on First Run.
		whiptail --title "No Modules" --backtitle "$TUI_VER" --msgbox "No modules detected!\nIf this is your first time using Diatheke choose:\n>6) Install Bible/Dictionary modules< on the next menu.\nOtherwise there's a problem with the current module directory: $MODULES_DIR" 20 80 10
		MENUSELECT="6)" # Have the Install Modules option pre-selected for the user on Main Menu.
		fi
	fi
	if [ -z "$DICT_MOD" ]; then
		DICT_MOD=$(tail -n1 <<< "$DICTIONARIES")
		if [ -z "$DICT_MOD" ]; then
		DICT_MOD="NONE"
		fi
	fi
	if [ -z "$COMMEN_MOD" ]; then
		COMMEN_MOD=$(tail -n1 <<< "$COMMENTARIES")
		if [ -z "$COMMEN_MOD" ]; then
		COMMEN_MOD="NONE"
		fi
	fi
	if [ -z "$BOOK_MOD" ]; then
		BOOK_MOD=$(tail -n1 <<< "$BOOKS")
		if [ -z "$BOOK_MOD" ]; then
		BOOK_MOD="NONE"
		fi
	fi
}
############
setModules ## Call function

# Function to read loaded books and commentaries in full terminal width.
## This function is loaded during read_book() after select_chapter()
function read_chapter() {
	# echo "$BOOK" # Debug current BOOK in case function
	# echo "$BOOK_READING" # Debug currently selected BOOK_READING in case function
	# echo "$CHAPTER" # Debug currently selected CHAPTER in case function
	LAST_CHAPTER=$(echo "$CHAPTERS" | rev | cut -c3) # Regex to capture last chapter from CHAPTERS
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
		if [[ $COMMEN_READING == 1 ]]; then
			## If commentary reading variable is set, read from Commentary Module instead of Bible Module.
			MOD_READING=$COMMEN_MOD
		else
			## Read Bible module
			MOD_READING=$BIBLE_MOD
		fi
		## To fix weird character display issues in some terminals, we use iconv.
		if (whiptail --title "Chapter $CHAPTER" --yes-button "Next Chp." --no-button "Main Menu" --scrolltext --yesno "$(iconv -f UTF8 -t US-ASCII//TRANSLIT <<< $(diatheke -b "$MOD_READING" -l "$LOCALE" -k "$BOOK_READING""$CHAPTER"))" $(stty size)) then
			if [[ $CHAPTER == "$LAST_CHAPTER" ]]; then
				## Detect last chapter and move to next book.
				let "BOOK=BOOK+1"
				let "CHAPTER=1"
				read_book
			else
				## Go to next chapter
				let "CHAPTER=CHAPTER+1"
				read_chapter ## Restart this function
			fi
		else
			let "CHAPTER=CHAPTER" ## Preserve last selected chapter even when we return to Main Menu.
			echo "Returned to Main Menu."
		fi
	else
		echo "Chapter Selection: Cancled."
	fi
}
#######################################

## Core function to select Bible books with nested function for chapters.
function read_book() {
	BOOK=$(
	whiptail --title "Choose Book" --default-item "$BOOK" --backtitle "$TUI_VER" --menu "Make your choice" 16 100 9 \
	"1" "Genesis" \
	"2" "Exodus" \
	"3" "Leviticus" \
	"4" "Numbers" \
	"5" "Deuteronomy" \
	"6" "Joshua" \
	"7" "Judges" \
	"8" "Ruth" \
	"9" "1 Samuel" \
	"10" "2 Samuel" \
	"11" "1 Kings" \
	"12" "2 Kings" \
	"13" "1 Chronicles" \
	"14" "2 Chronicles" \
	"15" "Ezra" \
	"16" "Nehemiah" \
	"17" "Esther" \
	"18" "Job" \
	"19" "Psalms" \
	"20" "Proverbs" \
	"21" "Ecclesiastes" \
	"22" "Song of Songs" \
	"23" "Isaiah" \
	"24" "Jeremiah" \
	"25" "Lamentations" \
	"26" "Ezekiel" \
	"27" "Daniel" \
	"28" "Hosea" \
	"29" "Joel" \
	"30" "Amos" \
	"31" "Obadiah" \
	"32" "Jonah" \
	"33" "Micah" \
	"34" "Nahum" \
	"35" "Habakkuk" \
	"36" "Zephaniah" \
	"37" "Haggai" \
	"38" "Zechariah" \
	"39" "Malachi" \
	"40" "Matthew" \
	"41" "Mark" \
	"42" "Luke" \
	"43" "John" \
	"44" "Acts" \
	"45" "Romans" \
	"46" "1 Corinthians" \
	"47" "2 Corinthians" \
	"48" "Galatians" \
	"49" "Ephesians" \
	"50" "Philippians" \
	"51" "Colossians" \
	"52" "1 Thessalonians" \
	"53" "2 Thessalonians" \
	"54" "1 Timothy" \
	"55" "2 Timothy" \
	"56" "Titus" \
	"57" "Philemon" \
	"58" "Hebrews" \
	"59" "James" \
	"60" "1 Peter" \
	"61" "2 Peter" \
	"62" "1 John" \
	"63" "2 John" \
	"64" "3 John" \
	"65" "Jude" \
	"66" "Revelation" 3>&2 2>&1 1>&3
	)
	## Read Bible -> Book Selection -> Chapter Selection
	function select_chapter() {
	CHAPTER=$(whiptail --title "Choose Chapter" --default-item "$CHAPTER" --menu "Make your choice" 16 100 9 $CHAPTERS 3>&2 2>&1 1>&3)
	}
	case $BOOK in
	"1")
	BOOK_READING="gen"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-" 32 "-" 33 "-" 34 "-" 35 "-" 36 "-" 37 "-" 38 "-" 39 "-" 40 "-" 41 "-" 42 "-" 43 "-" 44 "-" 45 "-" 46 "-" 47 "-" 48 "-" 49 "-" 50 "-""
	select_chapter
	read_chapter
	;;
	"2")
	BOOK_READING="exo"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-" 32 "-" 33 "-" 34 "-" 35 "-" 36 "-" 37 "-" 38 "-" 39 "-" 40 "-""
	select_chapter
	read_chapter
	;;
	"3")
	BOOK_READING="levi"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-""
	select_chapter
	read_chapter
	;;
	"4")
	BOOK_READING="num"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-" 32 "-" 33 "-" 34 "-" 35 "-" 36 "-""
	select_chapter
	read_chapter
	;;
	"5")
	BOOK_READING="deut"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-" 32 "-" 33 "-" 34 "-""
	select_chapter
	read_chapter
	;;
	"6")
	BOOK_READING="josh"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-""
	select_chapter
	read_chapter
	;;
	"7")
	BOOK_READING="judg"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-""
	select_chapter
	read_chapter
	;;
	"8")
	BOOK_READING="ruth"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-""
	select_chapter
	read_chapter
	;;
	"9")
	BOOK_READING="1sam"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-""
	select_chapter
	read_chapter
	;;
	"10")
	BOOK_READING="2sam"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-""
	select_chapter
	read_chapter
	;;
	"11")
	BOOK_READING="1king"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-""
	select_chapter
	read_chapter
	;;
	"12")
	BOOK_READING="2king"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-""
	select_chapter
	read_chapter
	;;
	"13")
	BOOK_READING="1chron"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-""
	select_chapter
	read_chapter
	;;
	"14")
	BOOK_READING="2chron"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-" 32 "-" 33 "-" 34 "-" 35 "-" 36 "-""
	select_chapter
	read_chapter
	;;
	"15")
	BOOK_READING="ezra"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-""
	select_chapter
	read_chapter
	;;
	"16")
	BOOK_READING="nehe"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-""
	select_chapter
	read_chapter
	;;
	"17")
	BOOK_READING="esth"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-""
	select_chapter
	read_chapter
	;;
	"18")
	BOOK_READING="job"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-" 32 "-" 33 "-" 34 "-" 35 "-" 36 "-" 37 "-" 38 "-" 39 "-" 40 "-" 41 "-" 42 "-""
	select_chapter
	read_chapter
	;;
	"19")
	BOOK_READING="psalm"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-" 32 "-" 33 "-" 34 "-" 35 "-" 36 "-" 37 "-" 38 "-" 39 "-" 40 "-" 41 "-" 42 "-" 43 "-" 44 "-" 45 "-" 46 "-" 47 "-" 48 "-" 49 "-" 50 "-" 51 "-" 52 "-" 53 "-" 54 "-" 55 "-" 56 "-" 57 "-" 58 "-" 59 "-" 60 "-" 61 "-" 62 "-" 63 "-" 64 "-" 65 "-" 66 "-" 67 "-" 68 "-" 69 "-" 70 "-" 71 "-" 72 "-" 73 "-" 74 "-" 75 "-" 76 "-" 77 "-" 78 "-" 79 "-" 80 "-" 81 "-" 82 "-" 83 "-" 84 "-" 85 "-" 86 "-" 87 "-" 88 "-" 89 "-" 90 "-" 91 "-" 92 "-" 93 "-" 94 "-" 95 "-" 96 "-" 97 "-" 98 "-" 99 "-" 100 "-" 101 "-" 102 "-" 103 "-" 104 "-" 105 "-" 106 "-" 107 "-" 108 "-" 109 "-" 110 "-" 111 "-" 112 "-" 113 "-" 114 "-" 115 "-" 116 "-" 117 "-" 118 "-" 119 "-" 120 "-" 121 "-" 122 "-" 123 "-" 124 "-" 125 "-" 126 "-" 127 "-" 128 "-" 129 "-" 130 "-" 131 "-" 132 "-" 133 "-" 134 "-" 135 "-" 136 "-" 137 "-" 138 "-" 139 "-" 140 "-" 141 "-" 142 "-" 143 "-" 144 "-" 145 "-" 146 "-" 147 "-" 148 "-" 149 "-" 150 "-""
	select_chapter
	read_chapter
	;;
	"20")
	BOOK_READING="prov"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-""
	select_chapter
	read_chapter
	;;
	"21")
	BOOK_READING="eccle"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-""
	select_chapter
	read_chapter
	;;
	"22")
	BOOK_READING="song"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-""
	select_chapter
	read_chapter
	;;
	"23")
	BOOK_READING="isai"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-" 32 "-" 33 "-" 34 "-" 35 "-" 36 "-" 37 "-" 38 "-" 39 "-" 40 "-" 41 "-" 42 "-" 43 "-" 44 "-" 45 "-" 46 "-" 47 "-" 48 "-" 49 "-" 50 "-" 51 "-" 52 "-" 53 "-" 54 "-" 55 "-" 56 "-" 57 "-" 58 "-" 59 "-" 60 "-" 61 "-" 62 "-" 63 "-" 64 "-" 65 "-" 66 "-""
	select_chapter
	read_chapter
	;;
	"24")
	BOOK_READING="jerem"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-" 32 "-" 33 "-" 34 "-" 35 "-" 36 "-" 37 "-" 38 "-" 39 "-" 40 "-" 41 "-" 42 "-" 43 "-" 44 "-" 45 "-" 46 "-" 47 "-" 48 "-" 49 "-" 50 "-" 51 "-" 52 "-""
	select_chapter
	read_chapter
	;;
	"25")
	BOOK_READING="lamen"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-""
	select_chapter
	read_chapter
	;;
	"26")
	BOOK_READING="ezek"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-" 29 "-" 30 "-" 31 "-" 32 "-" 33 "-" 34 "-" 35 "-" 36 "-" 37 "-" 38 "-" 39 "-" 40 "-" 41 "-" 42 "-" 43 "-" 44 "-" 45 "-" 46 "-" 47 "-" 48 "-""
	select_chapter
	read_chapter
	;;
	"27")
	BOOK_READING="dan"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-""
	select_chapter
	read_chapter
	;;
	"28")
	BOOK_READING="hose"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-""
	select_chapter
	read_chapter
	;;
	"29")
	BOOK_READING="joel"
	CHAPTERS="1 "-" 2 "-" 3 "-""
	select_chapter
	read_chapter
	;;
	"30")
	BOOK_READING="amos"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-""
	select_chapter
	read_chapter
	;;
	"31")
	BOOK_READING="obad"
	CHAPTERS="1 "-""
	select_chapter
	read_chapter
	;;
	"32")
	BOOK_READING="jona"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-""
	select_chapter
	read_chapter
	;;
	"33")
	BOOK_READING="mica"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-""
	select_chapter
	read_chapter
	;;
	"34")
	BOOK_READING="nahu"
	CHAPTERS="1 "-" 2 "-" 3 "-""
	select_chapter
	read_chapter
	;;
	"35")
	BOOK_READING="habak"
	CHAPTERS="1 "-" 2 "-" 3 "-""
	select_chapter
	read_chapter
	;;
	"36")
	BOOK_READING="zeph"
	CHAPTERS="1 "-" 2 "-" 3 "-""
	select_chapter
	read_chapter
	;;
	"37")
	BOOK_READING="hagg"
	CHAPTERS="1 "-" 2 "-""
	select_chapter
	read_chapter
	;;
	"38")
	BOOK_READING="zech"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-""
	select_chapter
	read_chapter
	;;
	"39")
	BOOK_READING="mala"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-""
	select_chapter
	read_chapter
	;;
	"40")
	BOOK_READING="matt"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-""
	select_chapter
	read_chapter
	;;
	"41")
	BOOK_READING="mark"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-""
	select_chapter
	read_chapter
	;;
	"42")
	BOOK_READING="luke"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-""
	select_chapter
	read_chapter
	;;
	"43")
	BOOK_READING="john"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-""
	select_chapter
	read_chapter
	;;
	"44")
	BOOK_READING="act"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-" 23 "-" 24 "-" 25 "-" 26 "-" 27 "-" 28 "-""
	select_chapter
	read_chapter
	;;
	"45")
	BOOK_READING="roman"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-""
	select_chapter
	read_chapter
	;;
	"46")
	BOOK_READING="1corin"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-""
	select_chapter
	read_chapter
	;;
	"47")
	BOOK_READING="2corin"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-""
	select_chapter
	read_chapter
	;;
	"48")
	BOOK_READING="galat"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-""
	select_chapter
	read_chapter
	;;
	"49")
	BOOK_READING="ephe"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-""
	select_chapter
	read_chapter
	;;
	"50")
	BOOK_READING="philip"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-""
	select_chapter
	read_chapter
	;;
	"51")
	BOOK_READING="coloss"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-""
	select_chapter
	read_chapter
	;;
	"52")
	BOOK_READING="1thessa"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-""
	select_chapter
	read_chapter
	;;
	"53")
	BOOK_READING="2thessa"
	CHAPTERS="1 "-" 2 "-" 3 "-""
	select_chapter
	read_chapter
	;;
	"54")
	BOOK_READING="1timo"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-""
	select_chapter
	read_chapter
	;;
	"55")
	BOOK_READING="2timo"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-""
	select_chapter
	read_chapter
	;;
	"56")
	BOOK_READING="titus"
	CHAPTERS="1 "-" 2 "-" 3 "-""
	select_chapter
	read_chapter
	;;
	"57")
	BOOK_READING="philem"
	CHAPTERS="1 "-""
	select_chapter
	read_chapter
	;;
	"58")
	BOOK_READING="hebrew"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-""
	select_chapter
	read_chapter
	;;
	"59")
	BOOK_READING="james"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-""
	select_chapter
	read_chapter
	;;
	"60")
	BOOK_READING="1peter"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-""
	select_chapter
	read_chapter
	;;
	"61")
	BOOK_READING="2peter"
	CHAPTERS="1 "-" 2 "-" 3 "-""
	select_chapter
	read_chapter
	;;
	"62")
	BOOK_READING="1john"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-""
	select_chapter
	read_chapter
	;;
	"63")
	BOOK_READING="2john"
	CHAPTERS="1 "-""
	select_chapter
	read_chapter
	;;
	"64")
	BOOK_READING="3john"
	CHAPTERS="1 "-""
	select_chapter
	read_chapter
	;;
	"65")
	BOOK_READING="jude"
	CHAPTERS="1 "-""
	select_chapter
	read_chapter
	;;
	"66")
	BOOK_READING="revel"
	CHAPTERS="1 "-" 2 "-" 3 "-" 4 "-" 5 "-" 6 "-" 7 "-" 8 "-" 9 "-" 10 "-" 11 "-" 12 "-" 13 "-" 14 "-" 15 "-" 16 "-" 17 "-" 18 "-" 19 "-" 20 "-" 21 "-" 22 "-""
	select_chapter
	read_chapter
	;;
	esac
}
#####################

clear

while true
do

## Main Menu Loop
CHOICE=$(
whiptail --nocancel --title "Main Menu" --backtitle "$TUI_VER" --default-item "$MENUSELECT" --menu "Welcome to Diatheke! Please make your selection. \nModules Loaded: Bible: $BIBLE_MOD / Dictionary: $DICT_MOD\n                Commentary: $COMMEN_MOD / Book: $BOOK_MOD" 20 80 10 \
	"1)" "Read Bible"  \
	"2)" "Read Commentary" \
	"3)" "Read Generic Book (Not Implemented)" \
	"4)" "Jump to Verse" \
	"5)" "Lookup Keyword" \
	"6)" "Install Bible/Dictionary modules" \
	"7)" "Install Commentary/Book modules" \
	"8)" "Choose Bible/Dictionary modules"   \
	"9)" "Choose Commentary/Book modules"   \
	"10)" "View & Download Images/Maps"   \
	"11)" "Exit"  3>&2 2>&1 1>&3
)

case $CHOICE in
	"1)")
	## Read Bible -> Book Selection
	COMMEN_READING="0" # We make sure to set this back to zero if returning from commentary reading mode.
	read_book ## Call this function
	;;
	"2)")
	## Read Commentary
	COMMEN_READING="1" # Trick book reading function into loading commentary module.
	read_book
        ;;
	"3)")
	whiptail --title "Unsupported!" --backtitle "$TUI_VER" --msgbox "Your module: $BOOK_MOD\nCannot be read in Diatheke yet.\nHopefully in a newer version!" 10 80 10
	;;
	"4)")
	## Jump to Verse
	VERSE=$(whiptail --title "Jump to Verse" --backtitle "$TUI_VER" --inputbox "Syntax: BookChapter:Verse\nExample: gen1:1" 10 60 3>&1 1>&2 2>&3)
	## If user input text, continue, else cancle.
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
		## To fix weird character display issues in some terminals, we use iconv.
		whiptail --scrolltext --textbox /dev/stdin $(stty size) <<<"$(iconv -f UTF8 -t US-ASCII//TRANSLIT <<< $(diatheke -b "$BIBLE_MOD" -l "$LOCALE" -k "$VERSE"))"
	else
	echo "Jump to Verse: Canceled."
	fi
        ;;
	"5)")
	## Lookup
	if (whiptail --title "Lookup" --backtitle "$TUI_VER" --yes-button "Bible" --no-button "Dictionary"  --yesno "What do you wish to Search?" 10 60) then
	## Lookup -> Bible
		BIBLE_KEYWORD=$(whiptail --title "Search Bible" --inputbox "Type a keyword to lookup." 10 60 3>&1 1>&2 2>&3)
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
		whiptail --scrolltext --textbox /dev/stdin $(stty size) <<<"$(diatheke -b "$BIBLE_MOD" -l "$LOCALE" -s phrase -k "$BIBLE_KEYWORD")"
		else
		echo "Bible Lookup: Canceled."
		fi
	else
	## Lookup -> Dictionary
		DICT_KEYWORD=$(whiptail --title "Search Dictionary" --inputbox "Type a keyword to lookup." 10 60 3>&1 1>&2 2>&3)
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			## To fix weird character display issues in some terminals, we use iconv.
			whiptail --scrolltext --textbox /dev/stdin $(stty size) <<<"$(iconv -f UTF8 -t US-ASCII//TRANSLIT <<< $(diatheke -b "$DICT_MOD" -l "$LOCALE" -k "$DICT_KEYWORD"))"
		else
		echo "Dictionary Lookup: Canceled."
		fi
	fi
	;;
	## Install modules
	"6)")
	if (whiptail --title "Install Modules" --yes-button "Bible" --no-button "Dictionary"  --yesno "What type of module do you wish to download?" 10 60) then
		## Regex to grab bibles from CrossWire repo
		GET_BIBLES=$(curl --silent "https://www.crosswire.org/sword/modules/ModDisp.jsp?modType=Bibles" 2>&1 | grep "SwordMod.Verify?modName=" |  sed -e 's/^.*\(modName=.*&pkgType\).*$/\1/' -e 's/modName=//' -e 's/&pkgType//')
		## Whiptail menu of above CrossWire array
		BIBLE_MOD=$(whiptail --title "Choose Bible Module" --backtitle "$TUI_VER" --menu "Pick a Bible module to be downloaded from Crosswire.org" 20 80 10 $(for x in $GET_BIBLES; do echo "$x" "-"; done) 3>&2 2>&1 1>&3)
		## Check if menu cancled, else continue
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			nohup curl "https://www.crosswire.org/ftpmirror/pub/sword/packages/rawzip/$BIBLE_MOD.zip" -o "$SWORD_DIR"/"$BIBLE_MOD".zip 2>&1 -# | stdbuf -oL tr '\r' '\n' | grep -o '[0-9]*\.' &> /tmp/module_down &
			{
			for ((i = 0 ; i <= 100 ; ++i)); do
				## Make up "fake" percentage until curl actually reaches 100.
				if [[ $(tail -1 "/tmp/module_down") = "100." ]]
					then
					## Set to 99 for a short time to let user know download is finished.
					i="99"
					echo $i
					sleep 2
					i="100"
					echo $i
				else
					## Keeps adding 1%
					sleep 1
					echo $i
				fi
			done
			} | whiptail --gauge "Please wait while downloading module..." 6 60 0
			rm /tmp/module_down ## Cleanup temp download progress file.

			## Check for file integrity
			if [ "$(unzip -t "$SWORD_DIR"/"$BIBLE_MOD".zip | grep "No errors")" ]; then
			## Install it and inform the user
			echo "FILE OK!"
			unzip "$SWORD_DIR"/"$BIBLE_MOD".zip -d "$SWORD_DIR"
			whiptail --title "Success!" --backtitle "$TUI_VER" --msgbox "Your module: $BIBLE_MOD was installed to $MODULES_DIR." 10 80 10
			else [ "$(unzip -t "$SWORD_DIR"/"$BIBLE_MOD".zip | grep "At least one")" ]
				echo "FILE CORRUPT!"
				## Delete it and warn the user
				rm "$SWORD_DIR"/"$BIBLE_MOD".zip
				whiptail --title "FAILED!" --backtitle "$TUI_VER" --msgbox "Download was corrupted! Please check your internet connection and try again." 10 80 10
		fi
	else
		# echo "Install Modules->Bible: Canceled."
		setModules # Requery modules if user cancled.
		## Note: Remove this function to avoid re-shuffle of modules, at the expense of not auto-loading newly installed ones.
	fi
	else
		## Regex to grab dictionaries from CrossWire repo
		GET_DICTS=$(curl --silent "https://www.crosswire.org/sword/modules/ModDisp.jsp?modType=Dictionaries" 2>&1 | grep "SwordMod.Verify?modName=" |  sed -e 's/^.*\(modName=.*&pkgType\).*$/\1/' -e 's/modName=//' -e 's/&pkgType//')
		## Whiptail menu of above CrossWire array
		DICT_MOD=$(whiptail --title "Choose Bible Module" --backtitle "$TUI_VER" --menu "Pick a Dictionary module to be downloaded from Crosswire.org" 20 80 10 $(for x in $GET_DICTS; do echo "$x" "-"; done) 3>&2 2>&1 1>&3)
		## Check if menu cancled, else continue
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			nohup curl "https://www.crosswire.org/ftpmirror/pub/sword/packages/rawzip/$DICT_MOD.zip" -o "$SWORD_DIR"/"$DICT_MOD".zip 2>&1 -# | stdbuf -oL tr '\r' '\n' | grep -o '[0-9]*\.' &> /tmp/module_down &
			{
			for ((i = 0 ; i <= 100 ; ++i)); do
				## Make up "fake" percentage until curl actually reaches 100.
				if [[ $(tail -1 "/tmp/module_down") = "100." ]]
					then
					## Set to 99 for a short time to let user know download is finished.
					i="99"
					echo $i
					sleep 2
					i="100"
					echo $i
				else
					## Keeps adding 1%
					sleep 1
					echo $i
				fi
			done
			} | whiptail --gauge "Please wait while downloading module..." 6 60 0
			rm /tmp/module_down ## Cleanup temp download progress file.

			## Check for file integrity
			if [ "$(unzip -t "$SWORD_DIR"/"$DICT_MOD".zip | grep "No errors")" ]; then
			## Install it and inform the user
			echo "FILE OK!"
			unzip "$SWORD_DIR"/"$DICT_MOD".zip -d "$SWORD_DIR"
			whiptail --title "Success!" --backtitle "$TUI_VER" --msgbox "Your module: $DICT_MOD was installed to $MODULES_DIR." 10 80 10
			else [ "$(unzip -t "$SWORD_DIR"/"$BIBLE_MOD".zip | grep "At least one")" ]
				echo "FILE CORRUPT!"
				## Delete it and warn the user
				rm "$SWORD_DIR"/"$DICT_MOD".zip
				whiptail --title "FAILED!" --backtitle "$TUI_VER" --msgbox "Download was corrupted! Please check your internet connection and try again." 10 80 10
			fi
		else
			# "Install Modules->Dictionary: Canceled."
			setModules # Requery modules if user cancled.
		fi
	fi
	;;
	"7)")
	if (whiptail --title "Install Extra-Modules" --yes-button "Commentary" --no-button "Generic Book"  --yesno "What type of extra-module do you wish to download?" 10 60) then
		## Regex to grab commentaries from CrossWire repo
		GET_COMMEN=$(curl --silent "https://www.crosswire.org/sword/modules/ModDisp.jsp?modType=Commentaries" 2>&1 | grep "SwordMod.Verify?modName=" |  sed -e 's/^.*\(modName=.*&pkgType\).*$/\1/' -e 's/modName=//' -e 's/&pkgType//')
		## Whiptail menu of above CrossWire array
		COMMEN_MOD=$(whiptail --title "Choose Commentary Module" --backtitle "$TUI_VER" --menu "Pick a Commentary module to be downloaded from Crosswire.org" 20 80 10 $(for x in $GET_COMMEN; do echo "$x" "-"; done) 3>&2 2>&1 1>&3)
		## Check if menu cancled, else continue
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			nohup curl "https://www.crosswire.org/ftpmirror/pub/sword/packages/rawzip/$COMMEN_MOD.zip" -o "$SWORD_DIR"/"$COMMEN_MOD".zip 2>&1 -# | stdbuf -oL tr '\r' '\n' | grep -o '[0-9]*\.' &> /tmp/module_down &
			{
			for ((i = 0 ; i <= 100 ; ++i)); do
				## Make up "fake" percentage until curl actually reaches 100.
				if [[ $(tail -1 "/tmp/module_down") = "100." ]]
					then
					## Set to 99 for a short time to let user know download is finished.
					i="99"
					echo $i
					sleep 2
					i="100"
					echo $i
				else
					## Keeps adding 1%
					sleep 1
					echo $i
				fi
			done
			} | whiptail --gauge "Please wait while downloading module..." 6 60 0
			rm /tmp/module_down ## Cleanup temp download progress file.

			## Check for file integrity
			if [ "$(unzip -t "$SWORD_DIR"/"$COMMEN_MOD".zip | grep "No errors")" ]; then
			## Install it and inform the user
			echo "FILE OK!"
			unzip "$SWORD_DIR"/"$COMMEN_MOD".zip -d "$SWORD_DIR"
			whiptail --title "Success!" --backtitle "$TUI_VER" --msgbox "Your module: $COMMEN_MOD was installed to $MODULES_DIR." 10 80 10
			else [ "$(unzip -t "$SWORD_DIR"/"$COMMEN_MOD".zip | grep "At least one")" ]
				echo "FILE CORRUPT!"
				## Delete it and warn the user
				rm "$SWORD_DIR"/"$COMMEN_MOD".zip
				whiptail --title "FAILED!" --backtitle "$TUI_VER" --msgbox "Download was corrupted! Please check your internet connection and try again." 10 80 10
		fi
	else
		# "Install Extra-Modules->Commentary: Canceled."
		setModules # Requery modules if user cancled.
	fi
	else
		## Regex to grab books from CrossWire repo
		GET_BOOKS=$(curl --silent "https://www.crosswire.org/sword/modules/ModDisp.jsp?modType=Books" 2>&1 | grep "SwordMod.Verify?modName=" |  sed -e 's/^.*\(modName=.*&pkgType\).*$/\1/' -e 's/modName=//' -e 's/&pkgType//')
		## Whiptail menu of above CrossWire array
		BOOK_MOD=$(whiptail --title "Choose Generic Book Module" --backtitle "$TUI_VER" --menu "Pick a Generic Book module to be downloaded from Crosswire.org" 20 80 10 $(for x in $GET_BOOKS; do echo "$x" "-"; done) 3>&2 2>&1 1>&3)
		## Check if menu cancled, else continue
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			nohup curl "https://www.crosswire.org/ftpmirror/pub/sword/packages/rawzip/$BOOK_MOD.zip" -o "$SWORD_DIR"/"$BOOK_MOD".zip 2>&1 -# | stdbuf -oL tr '\r' '\n' | grep -o '[0-9]*\.' &> /tmp/module_down &
			{
			for ((i = 0 ; i <= 100 ; ++i)); do
				## Make up "fake" percentage until curl actually reaches 100.
				if [[ $(tail -1 "/tmp/module_down") = "100." ]]
					then
					## Set to 99 for a short time to let user know download is finished.
					i="99"
					echo $i
					sleep 2
					i="100"
					echo $i
				else
					## Keeps adding 1%
					sleep 1
					echo $i
				fi
			done
			} | whiptail --gauge "Please wait while downloading module..." 6 60 0
			rm /tmp/module_down ## Cleanup temp download progress file.

			## Check for file integrity
			if [ "$(unzip -t "$SWORD_DIR"/"$BOOK_MOD".zip | grep "No errors")" ]; then
			## Install it and inform the user
			echo "FILE OK!"
			unzip "$SWORD_DIR"/"$BOOK_MOD".zip -d "$SWORD_DIR"
			whiptail --title "Success!" --backtitle "$TUI_VER" --msgbox "Your module: $BOOK_MOD was installed to $MODULES_DIR." 10 80 10
			else [ "$(unzip -t "$SWORD_DIR"/"$BOOK_MOD".zip | grep "At least one")" ]
				echo "FILE CORRUPT!"
				## Delete it and warn the user
				rm "$SWORD_DIR"/"$BOOK_MOD".zip
				whiptail --title "FAILED!" --backtitle "$TUI_VER" --msgbox "Download was corrupted! Please check your internet connection and try again." 10 80 10
			fi
		else
			# "Install Extra-Modules->Generic Book: Canceled."
			setModules # Requery modules if user cancled.
		fi
	fi
	;;
	"8)")
	getModules
	if (whiptail --title "Choose Modules" --backtitle "$TUI_VER" --yes-button "Bible" --no-button "Dictionary"  --yesno "What do you wish to set?" 10 60) then
	BIBLE_MOD=$(whiptail --nocancel --title "Choose Bible Module" --backtitle "$TUI_VER" --menu "Choose Bible Module" 20 80 10 $(for x in $BIBLES; do echo "$x" "-"; done) 3>&2 2>&1 1>&3)
	else
	DICT_MOD=$(whiptail --nocancel --title "Choose Dictionary Module" --backtitle "$TUI_VER" --menu "Choose Dictionary Module" 20 80 10 $(for x in $DICTIONARIES; do echo "$x" "-"; done) 3>&2 2>&1 1>&3)
	fi
	;;
	"9)")
	getModules
	if (whiptail --title "Choose Extra-Modules" --backtitle "$TUI_VER" --yes-button "Commentary" --no-button "Generic Book"  --yesno "What do you wish to set?" 10 60) then
	COMMEN_MOD=$(whiptail --nocancel --title "Choose Commentary Module" --backtitle "$TUI_VER" --menu "Choose Commentary Module" 20 80 10 $(for x in $COMMENTARIES; do echo "$x" "-"; done) 3>&2 2>&1 1>&3)
	else
	BOOK_MOD=$(whiptail --nocancel --title "Choose Generic Book Module" --backtitle "$TUI_VER" --menu "Choose Generic Book Module" 20 80 10 $(for x in $BOOKS; do echo "$x" "-"; done) 3>&2 2>&1 1>&3)
	fi
	;;
	"10)")
	if (whiptail --title "View or Download Images/Maps?" --backtitle "$TUI_VER" --yes-button "View" --no-button "Download"  --yesno "Do you wish to view or download Images/Maps?" 10 60) then
	IMAGE_MOD=$(whiptail --nocancel --title "Choose Image/Map Module" --backtitle "$TUI_VER" --menu "Choose Image/Map to view" 20 80 10 $(for x in $IMAGES; do echo "$x" "-"; done) 3>&2 2>&1 1>&3)
	IMAGE_CHOSEN=$(find "$SWORD_DIR" -name "$IMAGE_MOD")
	cacaview "$IMAGE_CHOSEN"
	else
		IMAGE_DOWN=$(whiptail --title "Choose Image/Map to Download" --menu "Make your choice" 16 100 9 absmaps "-" dorewoodcuts "-" epiphany-maps "-" histmideast "-" sonlightfreemaps "-" textbookatlas "-" 3>&2 2>&1 1>&3)
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			nohup curl "ftp://ftp.xiphos.org/pub/sword/zip/$IMAGE_DOWN.zip" -o "$SWORD_DIR"/"$IMAGE_DOWN".zip 2>&1 -# | stdbuf -oL tr '\r' '\n' | grep -o '[0-9]*\.' &> /tmp/module_down &
			{
			for ((i = 0 ; i <= 100 ; ++i)); do
				## Make up "fake" percentage until curl actually reaches 100.
				if [[ $(tail -1 "/tmp/module_down") = "100." ]]
					then
					## Set to 99 for a short time to let user know download is finished.
					i="99"
					echo $i
					sleep 2
					i="100"
					echo $i
				else
					## Keeps adding 1%
					sleep 1
					echo $i
				fi
			done
			} | whiptail --gauge "Please wait while downloading module..." 6 60 0
			rm /tmp/module_down ## Cleanup temp download progress file.

			## Check for file integrity
			if [ "$(unzip -t "$SWORD_DIR"/"$IMAGE_DOWN".zip | grep "No errors")" ]; then
			## Install it and inform the user
			echo "FILE OK!"
			unzip "$SWORD_DIR"/"$IMAGE_DOWN".zip -d "$SWORD_DIR"
			whiptail --title "Success!" --backtitle "$TUI_VER" --msgbox "Your module: $IMAGE_DOWN was installed to $MODULES_DIR." 10 80 10
			getModules ## Query installed modules to refresh list.
			else [ "$(unzip -t "$SWORD_DIR"/"$IMAGE_DOWN".zip | grep "At least one")" ]
				echo "FILE CORRUPT!"
				## Delete it and warn the user
				rm "$SWORD_DIR"/"$IMAGE_DOWN".zip
				whiptail --title "FAILED!" --backtitle "$TUI_VER" --msgbox "Download was corrupted! Please check your internet connection and try again." 10 80 10
			fi
		else
			# "Install Extra-Modules->Generic Book: Canceled."
			setModules # Requery modules if user cancled.
		fi
	fi
	;;
	"11)") exit
	;;
esac
done
exit