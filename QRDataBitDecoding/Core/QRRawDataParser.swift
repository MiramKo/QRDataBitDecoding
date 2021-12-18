///MIT License
//Copyright (c) 2021 Mikhail Kostrov (MiramKo)
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

import Foundation

///Glossary:
/// - Character - the character of the original text encoded in QR
/// - Symbol - the minimum element of a block of encoded information that can contain from one to several characters
/// - Block - a set of symbols encoded in the same encoding
///

//F.A.Q.
//rus(https://docs.cntd.ru/document/1200121043)
//eng(https://github.com/yansikeim/QR-Code/blob/master/ISO%20IEC%2018004%202015%20Standard.pdf)
enum QREncodingMode: Int {
    //Block encoding type (first 4 bits in raw data). Int value - value of first 4 bits in raw data
    case numeric = 1                //0001
    case alphaNumeric = 2           //0010
    case byte = 4                   //0100
    case kanji = 8                  //1000
    case structuredAppend = 3       //0011
    case eci = 7                    //0111
    case fnc1InFirstPosition = 5    //0101
    case fnc1InSecondPosition = 9   //1001
    case endPoint = 0               //0000
    
    
    //Number of bits for one simbol in initial data
    //In this semple project I will use only numeric, alphanumeric and byte encoding
    //about other encoding you can read in F.A.Q
    var numberOfBitsPerSymbol: Int? {
        switch self {
        case .numeric:
            return 10
        case .alphaNumeric:
            return 11
        case .byte:
            return 8
        default:
            return nil
        }
    }
    
    ///
    ///Returns the number of bits in which the number of encoded characters is written.
    ///For exemple:
    ///If we get the value "10", it means that the number of characters encoded in the block
    ///will be written in 10 bits following the first 4 bits (block encoding type).
    ///
    ///ATTENTION: in byte encoding number of "characters" equal to number of "symbols"
    func bitsSizeOfCharactersNumberIndicator(qrVersion: Int) -> Int? {
        switch self {
        case .numeric:
            switch qrVersion {
            case 1...9:
                return 10
            case 10...26:
                return 12
            case 27...40:
                return 14
            default:
                return nil
            }
        case .alphaNumeric:
            switch qrVersion {
            case 1...9:
                return 9
            case 10...26:
                return 11
            case 27...40:
                return 13
            default:
                return nil
            }
        case .byte:
            switch qrVersion {
            case 1...9:
                return 8
            case 10...26:
                return 16
            case 27...40:
                return 16
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

///
/// This project involves processing payment QR codes from Russia, where the first 8 characters of the source text contain service information.
/// The 7th character can have the values:
///     "1" - text encoding - CP1251
///     "2" - text encoding - UTF 8
///     "3" - text encoding - KOI8 R
///
final class QRRawDataParser {
    private var binaryData: BinaryData
    private var qrVersion: Int
    
    private var mode = QREncodingMode.endPoint
    private var numberOfBitsPerSymbol = 0
    private var charactersCount = 0
    
    private var encoding = String.Encoding.utf8
    private var isEncodingDefine = false
    
    private var stringValue = ""
    
    private let supportedModes: [QREncodingMode] = [.numeric, .alphaNumeric, .byte, .endPoint]
    private let modeBitsNumber = 4
    private let alphaNumericCharactersArray = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                                            "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
                                            "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
                                            " ", "$", "%", "*", "+", "-", ".", "/", ":"]
    
    init(with data: Data, qrVersion: Int) {
        self.qrVersion = qrVersion
        binaryData = BinaryData(data)
    }
    
    func getDecodedString() -> String? {
        //method to determine encoding for Russian payment QR
        defineEncoding()
        
        stringValue.removeAll()
        binaryData.resetBitPointer()
        
        //QR main consist of blocks with different encoding for each, for exemple:
        //[Numeric, Byte, Numeric, Alphanumeric, Numeric, Byte] etc
        //So we must define encoding mode of block befor its decoding
        //At the start we must define encoding of first block
        defineNextSegmentMode()
        
        //EndPoint - the end of the QR code data, there may be more bits after the "endpoint",
        //but they do not contain data and they do not need to be decoded
        while mode != .endPoint {
            //First we decode the block, and then we define the encoding mode of the next block,
            //so that when defining the ncoding mode as the "endpoint", we exit the loop
            decodeSegment()
            defineNextSegmentMode()
        }
        
        guard
            let data = stringValue.data(using: encoding),
            let result = String(data: data, encoding: encoding) else { return nil }
        
        return result
    }
    
    private func defineEncoding() {
        binaryData.resetBitPointer()
        
        defineNextSegmentMode()
        
        //Follow the same steps as in getDecodedString, but when we get 7 or more characters - try to define
        //the encoding of the payment QR
        while mode != .endPoint {
            decodeSegment()
            if stringValue.count > 6 {
                let value = String(stringValue.remove(at: stringValue.index(stringValue.startIndex, offsetBy: 6)))
                
                self.encoding = defineEncoding(forValue: value)
                isEncodingDefine = true
                stringValue.removeAll()
                
                break
            }
            defineNextSegmentMode()
        }
    }
    
    private func defineEncoding(forValue value: String) -> String.Encoding {
        switch value {
        case "1":
            return .windowsCP1251
        case "2":
            return .utf8
        case "3":
            let cfStringEncoding = CFStringEncoding(CFStringEncodings.KOI8_R.rawValue)
            let cocoaEncoding = CFStringConvertEncodingToNSStringEncoding(cfStringEncoding)
            return String.Encoding(rawValue: cocoaEncoding)
        default:
            return .utf8
        }
    }
    
    private func defineNextSegmentMode() {
        if
            //Get first 4 bits of block - encoding mode
            let value = binaryData.nextBits(count: modeBitsNumber),
            //Check if the encoding mode is supported
            let nextMode = QREncodingMode(rawValue: value),
            supportedModes.contains(nextMode) {
            mode = nextMode
        } else {
            //If the encoding mode is not supported or it was not possible to define it,
            //we set the endpoint to complete decoding
            mode = .endPoint
        }
    }
    
    private func decodeSegment() {
        switch mode {
        case .numeric:
            decodeNumericSegment()
        case .alphaNumeric:
            decodeAlphaNumericSegment()
        case .byte:
            decodeByteSegment()
        default:
            return
        }
    }
    
    ///
    /// In numeric encoding in one "symbol" coded three "characters"
    /// If the number of source "characters" is not a multiple of 3, then:
    ///     - One last "character" is encoded in a 4-bit "symbol"
    ///     - The last two "characters" are encoded in a 7-bit "symbol"
    ///
    private func decodeNumericSegment() {
        guard defineServiceInformation() else { return }
        let numberOfSymbols = charactersCount / 3
        
        var bufferText = ""
        for _ in 0..<numberOfSymbols {
            if let value = binaryData.nextBits(count: numberOfBitsPerSymbol) {
                //"Characters" can be similar to "145016" or "657004"(["145", "016"] or ["657", "004"])
                //In these cases, the last 3 digits "016" or "004" are encoded in one "symbol",
                //and we should not lose zeros
                if value < 10 {
                    bufferText += "00"
                } else if value < 100 {
                    bufferText += "0"
                }
                bufferText += String(value)
            }
        }
        
        let bitsOfOneAdditionalCharacter = 4
        let bitsOfTwoAdditionalCharacter = 7
        
        let additionalCharactersCount = charactersCount % 3
        if additionalCharactersCount == 1 {
            if let value = binaryData.nextBits(count: bitsOfOneAdditionalCharacter) {
                bufferText += String(value)
            }
        } else if additionalCharactersCount == 2 {
            if let value = binaryData.nextBits(count: bitsOfTwoAdditionalCharacter) {
                //We should not lose zeros in case like "34506" (["345", "06"])
                if value < 10 {
                    bufferText += "0"
                }
                bufferText += String(value)
            }
        }
        
        stringValue += bufferText
    }
    
    ///
    /// In alphanumeric encoding in one "symbol" coded two "characters"
    /// The array of alphanumeric characters is set by default in "alphaNumericCharactersArray"
    /// If the number of source "characters" is not a multiple of 2 then:
    ///     - One last "character" is encoded in a 6-bit "symbol"
    ///
    private func decodeAlphaNumericSegment() {
        guard defineServiceInformation() else { return }
        let numberOfSymbols = charactersCount / 2
        
        var bufferText = ""
        for _ in 0..<numberOfSymbols {
            if
                let value = binaryData.nextBits(count: numberOfBitsPerSymbol),
                (value / 45) < alphaNumericCharactersArray.count,
                (value % 45) < alphaNumericCharactersArray.count {
                bufferText += alphaNumericCharactersArray[value / 45] + alphaNumericCharactersArray[value % 45]
            }
        }
        
        let bitsOfOneAdditionalCharacter = 6
        if
            charactersCount % 2 != 0 ,
            let value = binaryData.nextBits(count: bitsOfOneAdditionalCharacter),
            value < alphaNumericCharactersArray.count {
            bufferText += alphaNumericCharactersArray[value]
        }
        
        stringValue += bufferText
    }
    
    ///
    /// In byte encoding in one "symbol" coded one "character"
    ///
    private func decodeByteSegment() {
        guard defineServiceInformation() else { return }
        var bytes = [UInt8]()
        for _ in 0..<charactersCount {
            if let value = binaryData.nextBits(count: numberOfBitsPerSymbol) {
                bytes.append(UInt8(value))
            }
        }
        
        stringValue += String(bytes: bytes, encoding: encoding) ?? ""
    }
    
    private func defineServiceInformation() -> Bool {
        guard
            let bitsInCharacterNumberIndicator = mode.bitsSizeOfCharactersNumberIndicator(qrVersion: qrVersion),
            let numberOfBitsPerSymbol = mode.numberOfBitsPerSymbol,
            let charactersCount = binaryData.nextBits(count: bitsInCharacterNumberIndicator) else { return false }
        self.numberOfBitsPerSymbol = numberOfBitsPerSymbol
        self.charactersCount = charactersCount
        return true
    }
}
