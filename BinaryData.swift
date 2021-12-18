//MIT License
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

final class BinaryData {
    private let bytes: [UInt8]
    private var currentBitPointer: Int = 0
    
    init(_ data: Data) {
        var byteArray = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &byteArray, count: data.count)
        bytes = byteArray
    }
    
    func nextBits(count: Int) -> Int? {
        if isNextBitsAvaliable(count: count) {
            let result = getBitsAt(startPoint: currentBitPointer, count: count)
            currentBitPointer += count
            return result
        }
        
        return nil
    }
    
    private func isNextBitsAvaliable(count: Int) -> Bool {
        return (bytes.count * 8) >= (currentBitPointer + count)
    }
    
    private func getBitsAt(startPoint: Int, count: Int) -> Int {
        var bitPositions = [Int]()
        
        for position in startPoint..<(startPoint + count) {
            bitPositions.append(position)
        }
        
        return bitPositions.reversed().enumerated().reduce(0) { $0 + (bitFor(position: $1.element) << $1.offset) }
    }
    
    private func bitFor(position: Int) -> Int {
        let byteSize = 8
        let bytePosition = position / byteSize
        let bitPosition = 7 - (position % byteSize)
        let byte = Int(bytes[bytePosition])
        return (byte >> bitPosition) & 0x01
    }
    
    func resetBitPointer() {
        currentBitPointer = 0
    }
}
