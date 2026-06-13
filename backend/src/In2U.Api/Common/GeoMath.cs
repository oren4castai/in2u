namespace In2U.Api.Common;

public readonly record struct OwnerRegion(long Id, double Lat, double Lng, int RadiusM);

public static class GeoMath
{
    private const double EarthRadiusMeters = 6_371_000.0;

    public static double DistanceMeters(double lat1, double lng1, double lat2, double lng2)
    {
        double lat1Rad = lat1 * Math.PI / 180.0;
        double lat2Rad = lat2 * Math.PI / 180.0;
        double meanLatRad = (lat1Rad + lat2Rad) / 2.0;

        double x = (lng2 - lng1) * Math.PI / 180.0 * Math.Cos(meanLatRad);
        double y = (lat2 - lat1) * Math.PI / 180.0;
        return Math.Sqrt(x * x + y * y) * EarthRadiusMeters;
    }

    // Nearest owner whose governance radius contains the point.
    // Ties on distance are broken by lowest owner Id.
    public static long? NearestGoverningOwner(double lat, double lng, IEnumerable<OwnerRegion> owners)
    {
        long? bestId = null;
        double bestDist = double.MaxValue;
        foreach (var o in owners)
        {
            var d = DistanceMeters(lat, lng, o.Lat, o.Lng);
            if (d > o.RadiusM) continue;
            if (d < bestDist || (d == bestDist && (bestId is null || o.Id < bestId)))
            {
                bestDist = d;
                bestId = o.Id;
            }
        }
        return bestId;
    }

    // Owners whose center is within thresholdM of the point, nearest first.
    public static IReadOnlyList<(long Id, double DistanceMeters)> OwnersWithin(
        double lat, double lng, int thresholdM, IEnumerable<OwnerRegion> owners)
    {
        var hits = new List<(long Id, double DistanceMeters)>();
        foreach (var o in owners)
        {
            var d = DistanceMeters(lat, lng, o.Lat, o.Lng);
            if (d <= thresholdM)
                hits.Add((o.Id, d));
        }
        hits.Sort((a, b) => a.DistanceMeters.CompareTo(b.DistanceMeters));
        return hits;
    }
}
