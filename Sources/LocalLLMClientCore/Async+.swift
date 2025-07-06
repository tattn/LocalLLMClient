package extension Array {
    /// Maps each element of the array asynchronously using the provided transform function.
    ///
    /// This method preserves the order of elements in the resulting array, applying the
    /// transformation function to each element in sequence.
    ///
    /// - Parameter transform: A function that transforms an element of the array asynchronously.
    /// - Returns: An array containing the transformed elements.
    /// - Throws: Rethrows any errors thrown by the transform function.
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        results.reserveCapacity(count)
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}

package extension Optional {
    /// Maps the wrapped value asynchronously using the provided transform function if it exists.
    ///
    /// - Parameter transform: A function that transforms the wrapped value asynchronously.
    /// - Returns: The transformed value if the original optional contains a value, otherwise nil.
    /// - Throws: Rethrows any errors thrown by the transform function.
    func asyncMap<T>(_ transform: (Wrapped) async throws -> T) async rethrows -> T? {
        if let value = self {
            return try await transform(value)
        } else {
            return nil
        }
    }
}
