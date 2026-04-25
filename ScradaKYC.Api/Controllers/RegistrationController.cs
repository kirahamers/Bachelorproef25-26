using Microsoft.AspNetCore.Mvc;

namespace ScradaKYC.Api.Controllers {

    [ApiController]
    [Route("api/[controller]")]
    public class registrationController : ControllerBase {
        [HttpPost("complete")]
        public IActionResult CompleteRegistration([FromBody] RegistrationRequest request)
        {
            if (request == null) return BadRequest("Geen data ontvangen.");

            //log om aan te tonen dat gegevens opgeslagen kunnen worden
            Console.WriteLine($"Bedrijf: {request.Bedrijfsnaam} (BTW: {request.BtwNummer})");
            Console.WriteLine($"Bestuurder: {request.BestuurderNaam}");
            Console.WriteLine($"Contact: {request.Email} | Tel: {request.Telefoon ?? "N/A"}");
            Console.WriteLine($"Biometrische Score: {request.MatchScore}%");

            //simulatie naar mailservice
            SimuleerEmailVerzending(request.Email, request.BestuurderNaam);

            return Ok(new { 
                success = true, 
                message = "Registratie succesvol verwerkt!" 
            });
        }

        private void SimuleerEmailVerzending(string email, string naam)
        {
            Console.WriteLine($"Verzend bevestiging naar: {email}");
            Console.WriteLine($"'Beste {naam}, bekijk uw mail om uw Scrada-account te verfieren!.'");
        }
    }

    public class RegistrationRequest
    {
        public string BtwNummer { get; set; }
        public string Bedrijfsnaam { get; set; }
        public string BestuurderNaam { get; set; }
        
        public string Email { get; set; }
        public string Telefoon { get; set; }
        public double MatchScore { get; set; }
    }
}