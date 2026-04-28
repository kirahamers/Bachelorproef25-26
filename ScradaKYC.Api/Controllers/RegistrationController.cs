using System.Xml.Serialization;
using Microsoft.AspNetCore.Mvc;
using ScradaKYC.Api.Services;

namespace ScradaKYC.Api.Controllers {

    [ApiController]
    [Route("api/[controller]")]
    public class registrationController : ControllerBase 
    {
        private readonly EncryptionService _encryptionService;

        public registrationController(EncryptionService encryptionService)
        {
            _encryptionService = encryptionService;
        }

        [HttpPost("complete")]
        public IActionResult CompleteRegistration([FromBody] RegistrationRequest request)
        {
            if (request == null) return BadRequest("Geen data ontvangen.");

            string email = _encryptionService.Encrypt(request.Email);
            string btw = _encryptionService.Encrypt(request.BtwNummer);
            string naam = _encryptionService.Encrypt(request.BestuurderNaam);

            Console.WriteLine("--- VEILIGE DATA VOOR OPSLAG ---");
            Console.WriteLine($"Gecrypteerd Email: {email}");
            Console.WriteLine($"Gecrypteerd BTW: {btw}");
            Console.WriteLine($"Gecrypteerde Bestuurder: {naam}");
            Console.WriteLine("--------------------------------");

            return Ok(new { 
                success = true, 
                message = "Data veilig versleuteld en klaar voor database!" 
            });
        }
    }
    public class RegistrationRequest
    {
        public string BtwNummer { get; set; } = string.Empty;
        public string Bedrijfsnaam { get; set; } = string.Empty;
        public string BestuurderNaam { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? Telefoon { get; set; } 
        public double MatchScore { get; set; }
    }
}