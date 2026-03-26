using Microsoft.AspNetCore.Mvc;

namespace ScradaKYC.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class KboController : ControllerBase
    {
        private readonly RiskService _riskService;

        public KboController(RiskService riskService)
        {
            _riskService = riskService;
        }

        [HttpGet("{ondernemingsnummer}")]
        public IActionResult GetCompanyInfo(string ondernemingsnummer)
        {
            try
            {
                string nummer = ondernemingsnummer.Replace(".", "").Replace(" ", "");

                string status = "ACTIVE";
                
                string risk = _riskService.CalculateRisk(status, nummer);

                var result = new
                {
                    enterprise_number = ondernemingsnummer,
                    name = "Scrada Test Bedrijf BV",
                    status = status,
                    sanction_check = "Cleared",
                    ubo_identified = true,
                    risk_score = risk,
                    directors = new[] { "Jane Doe", "John Doe" }
                };

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Fout: {ex.Message}");
            }
        }
    }
}