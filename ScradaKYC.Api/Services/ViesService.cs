using System.Text.Json;

namespace ScradaKYC.Api.Services
{
    public class ViesService
    {
        public async Task<(bool IsValid, string Name)> CheckVatNumber(string vatNumber)
        {
            //demo
            if (vatNumber.Contains("0123456789")) 
            {
                return (true, "DEMO ENTITEIT");
            }

            //BE zit in de URL, dus in principe kan gewoon ondernemingsnummer worden ingetypt
            var url = $"https://ec.europa.eu/taxation_customs/vies/rest-api/ms/BE/vat/{vatNumber}";
            using var client = new HttpClient();
            var response = await client.GetAsync(url);

            if (!response.IsSuccessStatusCode) 
            {
                return (false, "Onbekend");
            }

            var content = await response.Content.ReadAsStringAsync();
            var json = JsonDocument.Parse(content);
            var root = json.RootElement;

            bool isValid = root.GetProperty("isValid").GetBoolean();
            string name = root.GetProperty("name").GetString() ?? "Naam onbekend";

            Console.WriteLine(content);
            return (isValid, name);
        }
    }
}