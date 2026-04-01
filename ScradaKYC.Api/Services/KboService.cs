namespace ScradaKYC.Api.Services
{
    public class KboService
    {
        //WSConsultAgentEnterprise webservice
        public string[] GetBestuurders(string ondernemingsnummer)
        {
            //mock data
            return new[] { "Shakira Hamers" };
        }

        public string GetStatus(string ondernemingsnummer)
        {
            //mock data
            return "ACTIVE";
        }
    }
}