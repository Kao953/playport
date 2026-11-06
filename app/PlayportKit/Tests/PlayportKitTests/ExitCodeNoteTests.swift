// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
@testable import PlayportKit

final class ExitCodeNoteTests: XCTestCase {
    func testKnownCodesAndFallbacks() {
        XCTAssertNil(ExitCodeNote.explain(0))
        XCTAssertTrue(ExitCodeNote.line(0xC000_0005).hasPrefix("0xC0000005 (access violation"))
        XCTAssertTrue(ExitCodeNote.explain(0x42B)!.contains("Quit game"), "BUNNY GARDEN's end after Quit game")
        XCTAssertTrue(ExitCodeNote.explain(0xC000_0135)!.hasPrefix("DLL not found"))
        XCTAssertTrue(ExitCodeNote.explain(0xC000_0999)!.contains("NTSTATUS 0xC0000999"))
        XCTAssertTrue(ExitCodeNote.explain(2)!.contains("own error code 2"))
        XCTAssertEqual(ExitCodeNote.line(0), "0x00000000")
    }

    func testFileFailsKeepTheGamesMissingFilesLastFirst() {
        let log = """
        [file-fail] ml665 #2 NtCreateFile status=0xc0000034 disp=1 access=0x80100000 options=0x00000020 unix=/usr/local/share/fex-emu/Config.json name=\\??\\unix\\usr\\local\\share\\fex-emu\\Config.json
        title: in-app start Games\\X\\x.exe
        [file-fail] ml665 #3 NtCreateFile status=0xc0000034 disp=1 access=0x80100080 options=0x00000060 unix=(none) name=\\??\\C:\\Games\\X\\data\\level1.pak
        [file-fail] ml665 #4 NtCreateFile status=0xc000003a disp=1 access=0x80100080 options=0x00000060 unix=(none) name=\\??\\C:\\users\\playport\\Documents\\X\\save
        [file-fail] ml665 #5 NtCreateFile status=0xc0000034 disp=1 access=0x80100080 options=0x00000060 unix=(none) name=\\??\\C:\\Games\\X\\data\\level1.pak
        [file-fail] ml665 #6 NtCreateFile status=0xc0000034 disp=1 access=0x00110000 options=0x00201040 unix=(none) name=\\??\\C:\\users\\playport\\AppData\\Local\\Playport\\session\\request
        """
        XCTAssertEqual(FileFailNote.summary(log), [
            "C:\\Games\\X\\data\\level1.pak (not found)",
            "C:\\users\\playport\\Documents\\X\\save (folder not found)",
        ])
    }
}
