namespace In2U.Api.Common;

public sealed class InactiveTimeoutException : Exception
{
    public InactiveTimeoutException(string message) : base(message) { }
}
