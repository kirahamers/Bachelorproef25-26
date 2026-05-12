using System.Diagnostics;
using Xunit;
using Xunit.Abstractions;
using ScradaKYC.Api.Services;

namespace ScradaKYC.Tests
{
    public class KycPerformanceTests
    {
        private readonly ITestOutputHelper _output;
        private readonly ViesService _viesService;
        private readonly KboService _kboService;

        public KycPerformanceTests(ITestOutputHelper output)
        {
            _output = output;
            _viesService = new ViesService();
            _kboService = new KboService();
        }

        [Fact]
        public async Task Test_ViesAndKbo_CombinedSpeed()
        {
            string testNummer = "0403019261"; 
            var sw = Stopwatch.StartNew();

            var viesTask = _viesService.CheckVatNumber(testNummer);
            var kboTask = _kboService.GetBestuurders(testNummer);

            await Task.WhenAll(viesTask, kboTask);
            sw.Stop();

            _output.WriteLine($"Totale tijd {testNummer}: {sw.ElapsedMilliseconds}ms");
            
            Assert.True(sw.ElapsedMilliseconds < 500, "Traag");
        }

        [Fact]
        public async Task Test_RealKboScraping_Speed()
        {
            var sw = Stopwatch.StartNew();
            
            var result = await _kboService.GetBestuurders("0403019261"); 
            
            sw.Stop();
            _output.WriteLine($"KBO scraping: {sw.ElapsedMilliseconds}ms");
            
            Assert.True(sw.ElapsedMilliseconds < 2500, "KBO website te traag.");
        }
    }
}