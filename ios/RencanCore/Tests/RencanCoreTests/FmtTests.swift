import XCTest

@testable import RencanCore

// 數字寫成固定小數位（Formulas.fmt）。標準答案是網頁版 index.html 的 fmt 算出來的：
//   fmt=(n,d)=>(Math.round(n*10**d)/10**d).toFixed(d)
// 畫面上每一個小數都走這裡，兩邊差一位使用者就會看到不一樣的數字。

final class FmtTests: XCTestCase {
    func test剛好一半的時候進位() {
        XCTAssertEqual(Formulas.fmt(0.125, digits: 2), "0.13")
        XCTAssertEqual(Formulas.fmt(2.5, digits: 0), "3")
    }

    func test一般的四捨五入() {
        XCTAssertEqual(Formulas.fmt(20.316852, digits: 2), "20.32")
        XCTAssertEqual(Formulas.fmt(0.5544984, digits: 1), "0.6")
        XCTAssertEqual(Formulas.fmt(116.666, digits: 0), "117")
    }

    func test整數也補滿小數位() {
        XCTAssertEqual(Formulas.fmt(72, digits: 1), "72.0")
    }

    func test浮點數存不準的數字跟網頁版同一個結果() {
        // 1.005 在電腦裡其實是 1.00499…，網頁版寫成 1.00；19.995 乘 100 剛好是 1999.5，寫成 20.00。
        XCTAssertEqual(Formulas.fmt(1.005, digits: 2), "1.00")
        XCTAssertEqual(Formulas.fmt(19.995, digits: 2), "20.00")
    }
}
