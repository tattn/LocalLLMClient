#if canImport(CoreImage)
// // Alternative to stb_image.h
import Accelerate
import CoreImage

@_silgen_name("stbi_load_from_memory")
func stbi_load_from_memory(_ buffer:  UnsafePointer<UInt8>, _ len: UInt64, _ x: UnsafeMutablePointer<Int32>, _ y: UnsafeMutablePointer<Int32>, _ comp: UnsafeMutablePointer<Int32>, _ req_comp: Int32) -> UnsafeMutableRawPointer? {
    assert(req_comp == 3, "Only RGB format is supported")

    let data = Data(bytes: buffer, count: Int(len))
    guard let (rgbBytes, width, height) = imageDataToRGBBytes(imageData: data) else {
        print("Failed to convert image data to RGB bytes")
        return nil
    }

    x.pointee = Int32(width)
    y.pointee = Int32(height)

    return rgbBytes
}

@_silgen_name("stbi_load")
func stbi_load(_ filename: UnsafePointer<CChar>, _ x: UnsafeMutablePointer<Int32>, _ y: UnsafeMutablePointer<Int32>, _ comp: UnsafeMutablePointer<Int32>, _ req_comp: Int32) -> UnsafeMutableRawPointer? {
    assert(req_comp == 3, "Only RGB format is supported")

    guard let url = URL(string: String(cString: filename)),
          let imageData = try? Data(contentsOf: url),
          let (rgbBytes, width, height) = imageDataToRGBBytes(imageData: imageData) else {
        print("Failed to convert image data to RGB bytes")
        return nil
    }

    x.pointee = Int32(width)
    y.pointee = Int32(height)

    return rgbBytes
}

@_silgen_name("stbi_image_free")
func stbi_image_free(_ buffer: UnsafeMutableRawPointer) {
    buffer.assumingMemoryBound(to: UInt8.self).deallocate()
}

package func imageDataToRGBBytes(
    imageData: Data
) -> (bytes: UnsafeMutableRawPointer, width: Int, height: Int)? {
    let context = CIContext()
    let image = CIImage(data: imageData)!
    guard let cgImage = context.createCGImage(image, from: image.extent) else {
        return nil
    }

    var format = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 8 * 3,
        colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!,
        bitmapInfo: .init(rawValue: CGImageAlphaInfo.none.rawValue))!

    guard let buffer = try? vImage.PixelBuffer(
        cgImage: cgImage,
        cgImageFormat: &format,
        pixelFormat: vImage.Interleaved8x3.self) else {
        return nil
    }

    let width = cgImage.width
    let height = cgImage.height

    let result = UnsafeMutableRawBufferPointer.allocate(
        byteCount: width * height * 3,
        alignment: MemoryLayout<UInt8>.alignment
    )
    buffer.array.copyBytes(to: result)

    return (result.baseAddress!, width, height)
}
#else
import Foundation

@_silgen_name("stbi_load_from_memory")
func stbi_load_from_memory(_ buffer: UnsafePointer<UInt8>, _ len: Int32, _ x: UnsafeMutablePointer<Int32>, _ y: UnsafeMutablePointer<Int32>, _ comp: UnsafeMutablePointer<Int32>, _ req_comp: Int32) -> UnsafeMutablePointer<UInt8>?

package func imageDataToRGBBytes(
    imageData: Data
) -> (bytes: UnsafeMutableRawPointer, width: Int, height: Int)? {
    var width: Int32 = 0
    var height: Int32 = 0
    var comp: Int32 = 0
    return imageData.withUnsafeBytes { rawBufferPointer -> ((UnsafeMutableRawPointer, Int, Int)?) in
        guard let baseAddress = rawBufferPointer.baseAddress else { return nil }
        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
        return stbi_load_from_memory(pointer, Int32(imageData.count), &width, &height, &comp, 3).map { bytes in
            (UnsafeMutableRawPointer(bytes), Int(width), Int(height))
        }
    }
}
#endif
