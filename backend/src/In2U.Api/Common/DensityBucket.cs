namespace In2U.Api.Common;

public static class DensityBucket
{
    public static string From(int realCount) =>
        realCount switch
        {
            < 3 => "chill",
            < 15 => "vibing",
            _ => "packed",
        };
}
