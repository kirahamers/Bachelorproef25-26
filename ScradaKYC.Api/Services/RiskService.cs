public class RiskService
{
    public string CalculateRisk(string status, string ondernemingsnummer)
    {
        int score = 0;

        if (status?.ToUpper() != "ACTIVE") score += 70;

        string number = ondernemingsnummer.Replace(".", "").Replace(" ", "");
        if (number.Length != 10) score += 20;

        return score switch
        {
            < 30 => "Low",
            < 70 => "Medium",
            _ => "High"
        };
    }
}