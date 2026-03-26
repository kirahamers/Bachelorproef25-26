using ScradaKYC.Api.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddScoped<ViesService>();
builder.Services.AddScoped<KboService>();
builder.Services.AddScoped<LsegService>();
builder.Services.AddScoped<RiskService>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
    });
});

var app = builder.Build();
app.UseCors("AllowAll");
app.MapControllers();
app.Run();