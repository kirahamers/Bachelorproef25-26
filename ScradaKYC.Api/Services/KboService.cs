using HtmlAgilityPack;
using System.Net.Http;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Net;

namespace ScradaKYC.Api.Services
{
    public class KboService
    {
        //code geinspireerd op de code van Ninho Decaesteker
        public async Task<string[]> GetBestuurders(string ondernemingsnummer)
        {
            var schoonNummer = new string(ondernemingsnummer.Where(char.IsDigit).ToArray());
            if (schoonNummer.Length == 9) schoonNummer = "0" + schoonNummer;

            var url = $"https://kbopub.economie.fgov.be/kbopub/toonondernemingps.html?ondernemingsnummer={schoonNummer}";

            Console.WriteLine($"\n[KBO SCRAPER] Start check voor: {schoonNummer}");
            
            try
            {
                using var client = new HttpClient();
                client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");

                var html = await client.GetStringAsync(url);
                var doc = new HtmlDocument();
                doc.LoadHtml(html);

                var gevondenBestuurders = new List<string>();

                var nodes = doc.DocumentNode.SelectNodes("//tr[td[contains(., 'Bestuurder') or contains(., 'Vaste vertegenwoordiger') or contains(., 'Zaakvoerder') or contains(., 'Beheerder')]]");

                if (nodes != null)
                {
                    foreach (var node in nodes)
                    {
                        var cell = node.SelectSingleNode("td[2]");
                        if (cell != null)
                        {
                            var ruweTekst = System.Net.WebUtility.HtmlDecode(cell.InnerText).Trim();
                            
                            if (ruweTekst.Any(char.IsLetter))
                            {
                                var zonderNummer = ruweTekst.Split('(')[0];

                                var zonderKomma = zonderNummer.Replace(",", " ");

                                var schoneNaam = string.Join(" ", zonderKomma
                                    .Split(new[] { ' ', '\u00A0' }, StringSplitOptions.RemoveEmptyEntries))
                                    .Trim()
                                    .ToUpper();

                                if (!string.IsNullOrEmpty(schoneNaam))
                                {
                                    gevondenBestuurders.Add(schoneNaam);
                                }
                            }
                        }
                    }
                }

                return gevondenBestuurders.Distinct().ToArray();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"{ex.Message}");
                return new[] { "Geen bestuurders gevonden" };
            }
        }

        public string GetStatus(string ondernemingsnummer) => "ACTIVE";
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
