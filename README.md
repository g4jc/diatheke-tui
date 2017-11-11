# diatheke-tui
Diatheke-TUI is a [whiptail](https://linux.die.net/man/1/whiptail) Terminal User Interface to the [Diatheke](https://www.crosswire.org/wiki/Frontends:Diatheke) CLI program provided by [sword project](https://www.crosswire.org/sword/index.jsp).  :book:
This allows you to comfortably read the Bible within a virtual terminal, or even on a computer without Xorg-server.

This software was built for minimalists and is also useful for embedded devices/low powered computers that might not be able to run a full featured desktop bible software.  :computer:

## Features:

:white_check_mark: Install and Choose: Bibles, Commentaries, Books, Maps, and Images 

:white_check_mark: Read Bibles and Commentaries by Book/Chapter

:white_check_mark: Jump to a specific Verse

:white_check_mark: View Maps and Images with ASCII image viewer

:white_check_mark: Search Bibles and Commentaries

:white_check_mark: User-configurable default modules (inside script)

:no_entry_sign: Unsupported: Reading of Generic Books (No support in Diatheke CLI yet) 

## Dependencies

:red_circle: coreutils (sed, grep, gnu utilities) (Required) 

:red_circle: libsword (Required)

:red_circle: libnewt (Required)

:large_blue_circle: curl (Optional: Required for downloading modules) 

:large_blue_circle: unzip (Optional: Required for installing modules)

:large_blue_circle: libcaca (Optional: Required for viewing maps/images)

## Screenshots

### Main Menu
![main_menu](https://i.imgur.com/C4cJvTZ.png)

### Chapter Reading
![chapter_reading](https://i.imgur.com/uUBBK1t.png)

### Image Viewer
![image_viewer](https://i.imgur.com/IcFpIqI.png)
