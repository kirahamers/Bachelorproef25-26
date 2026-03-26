using Microsoft.AspNetCore.Mvc;
using ScradaKYC.Api.Services;

namespace ScradaKYC.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class KycController : ControllerBase
    {
        private readonly ViesService _viesService;
        private readonly KboService _kboService;
        private readonly RiskService _riskService;
        private readonly LsegService _lsegService;

        public KycController(ViesService viesService, KboService kboService, RiskService riskService, LsegService lsegService)
        {
            _viesService = viesService;
            _kboService = kboService;
            _riskService = riskService;
            _lsegService = lsegService;
        }

        [HttpGet("{ondernemingsnummer}")]
        public async Task<IActionResult> GetCompanyInfo(string ondernemingsnummer)
        {
            try
            {
                string schoonNummer = ondernemingsnummer.Replace(".", "").Replace(" ", "");

                //VIES -> BTW-nummer geldig? en haal de naam op
                var viesResult = await _viesService.CheckVatNumber(schoonNummer);
                if (!viesResult.IsValid)
                {
                    return BadRequest("Dit ondernemingsnummer is ongeldig of niet BTW-plichtig (VIES).");
                }

                //KBO (hardcoded)
                string kboStatus = _kboService.GetStatus(schoonNummer);
                string[] bestuurders = _kboService.GetBestuurders(schoonNummer);

                //LSEG (hardcoded)
                string sanctionStatus = _lsegService.CheckSanctions(viesResult.Name);

                //Risicoberekening via RiskService
                string risk = _riskService.CalculateRisk(kboStatus, schoonNummer);
                if (sanctionStatus != "Cleared") risk = "High";

                //JSON
                var result = new
                {
                    enterprise_number = ondernemingsnummer,
                    name = viesResult.Name,
                    status = kboStatus,
                    sanction_check = sanctionStatus,
                    risk_score = risk,
                    directors = bestuurders
                };

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Interne serverfout: {ex.Message}");
            }
        }
    }
}