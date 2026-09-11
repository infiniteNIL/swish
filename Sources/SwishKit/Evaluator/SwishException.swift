/// A value thrown by Swish code with `throw`.
///
/// Public because a host catching errors out of `Swish.eval`/`call` needs to see
/// what the Swish code threw — typically an `ExceptionInfo` record, including the
/// one Swish wraps around an error thrown by a registered Swift function.
public struct SwishException: Error {
    /// The thrown value.
    public let value: Expr

    init(value: Expr) {
        self.value = value
    }
}
