namespace ScradaKYC.Api.Services
{
    public class KboService
    {
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

//WSConsultAgentEnterprise webservice
    /*public class KboService
    {
        private readonly HttpClient _httpClient;
        private readonly string _apiKey;
        private readonly string _baseUrl = //URL ;eot hier komen

        public KboService(HttpClient httpClient, IConfiguration configuration)
        {
            _httpClient = httpClient;
            _apiKey = configuration["KBO:ApiKey"]; 
        }

        public async Task<string[]> GetBestuurders(string ondernemingsnummer)
        {
            try 
            {
                _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
                
                var response = await _httpClient.GetAsync($"{_baseUrl}{ondernemingsnummer}/officials");

                if (!response.IsSuccessStatusCode) return Array.Empty<string>();

                var content = await response.Content.ReadAsStringAsync();
                var kboData = JsonSerializer.Deserialize<KboOfficialsResponse>(content);

                return kboData.Officials
                    .Where(o => o.Role == "Bestuurder")
                    .Select(o => $"{o.FirstName} {o.LastName}")
                    .ToArray();
            }
            catch (Exception)
            {
                return Array.Empty<string>();
            }
        }

        public async Task<string> GetStatus(string ondernemingsnummer)
        {
            _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
            var response = await _httpClient.GetAsync($"{_baseUrl}{ondernemingsnummer}/status");

            if (!response.IsSuccessStatusCode) return "UNKNOWN";

            var content = await response.Content.ReadAsStringAsync();
            var statusData = JsonSerializer.Deserialize<KboStatusResponse>(content);

            return statusData.Status;
        }
    }

    public class KboOfficialsResponse { public List<Official> Officials { get; set; } }
    public class Official { public string FirstName { get; set; } public string LastName { get; set; } public string Role { get; set; } }
    public class KboStatusResponse { public string Status { get; set; } }*/
}