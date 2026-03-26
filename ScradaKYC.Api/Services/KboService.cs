using System.Net.Http;
using System.Text.Json;

public class KboService
{
    private readonly HttpClient _httpClient;

    public KboService(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<object> GetCompanyAsync(string ondernemingsnummer)
    {
        var url = $"https://kbopub.economie.fgov.be/kbo-open-data/api/enterprise/{ondernemingsnummer}";

        var response = await _httpClient.GetAsync(url);

        if (!response.IsSuccessStatusCode)
        {
            throw new Exception($"KBO API error: {response.StatusCode}");
        }

        var content = await response.Content.ReadAsStringAsync();

        var json = JsonDocument.Parse(content);

        var root = json.RootElement;

        var naam = root
            .GetProperty("denomination")
            .GetProperty("fullName")
            .GetString();

        var status = root.GetProperty("status").GetString();

        return new
        {
            enterprise_number = ondernemingsnummer,
            name = naam,
            status = status
        };
    }
}