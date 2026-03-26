namespace ScradaKYC.Api.Services
{
    //Dit is een mockup indien LSEG wel geïmplementeerd zou worden. Zie methodologie voor meer uitleg hierover.
    public class LsegService
    {
        public string CheckSanctions(string companyName)
        {
            if (string.IsNullOrEmpty(companyName)) return "Cleared";

            string lowerName = companyName.ToLower();
            if (lowerName.Contains("maffia") || lowerName.Contains("fraud") || lowerName.Contains("scam"))
            {
                return "Sanctioned (Match in World-Check)";
            }
            
            return "Cleared"; 
        }
    }
}