using Microsoft.EntityFrameworkCore;
using Todo.Api.Data;
using Todo.Api.DTOs;
using Todo.Api.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("TodoDb")));

const string corsPolicyName = "Frontend";
builder.Services.AddCors(options =>
{
    options.AddPolicy(corsPolicyName, policy =>
    {
        policy.WithOrigins(
                builder.Configuration.GetValue<string>("Frontend:Origin") ?? "http://localhost:5173")
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors(corsPolicyName);

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.EnsureCreatedAsync();
}

var todos = app.MapGroup("/api/todos");

todos.MapGet("/", async (AppDbContext db) =>
{
    var items = await db.TodoItems
        .AsNoTracking()
        .OrderBy(item => item.IsCompleted)
        .ThenByDescending(item => item.CreatedAtUtc)
        .Select(item => new TodoItemResponse(
            item.Id,
            item.Title,
            item.Description,
            item.IsCompleted,
            item.CreatedAtUtc,
            item.UpdatedAtUtc))
        .ToListAsync();

    return Results.Ok(items);
});

todos.MapPost("/", async (CreateTodoItemRequest request, AppDbContext db) =>
{
    var validationErrors = ValidateTodoInput(request.Title, request.Description);
    if (validationErrors.Count > 0)
    {
        return Results.ValidationProblem(validationErrors);
    }
    var trimmedTitle = request.Title.Trim();

    var item = new TodoItem
    {
        Title = trimmedTitle,
        Description = string.IsNullOrWhiteSpace(request.Description)
            ? null
            : request.Description.Trim(),
        IsCompleted = false,
        CreatedAtUtc = DateTime.UtcNow,
        UpdatedAtUtc = DateTime.UtcNow
    };

    db.TodoItems.Add(item);
    await db.SaveChangesAsync();

    return Results.Created($"/api/todos/{item.Id}", new TodoItemResponse(
        item.Id,
        item.Title,
        item.Description,
        item.IsCompleted,
        item.CreatedAtUtc,
        item.UpdatedAtUtc));
});

todos.MapPut("/{id:int}", async (int id, UpdateTodoItemRequest request, AppDbContext db) =>
{
    var validationErrors = ValidateTodoInput(request.Title, request.Description);
    if (validationErrors.Count > 0)
    {
        return Results.ValidationProblem(validationErrors);
    }
    var trimmedTitle = request.Title.Trim();

    var item = await db.TodoItems.FirstOrDefaultAsync(todo => todo.Id == id);
    if (item is null)
    {
        return Results.NotFound();
    }

    item.Title = trimmedTitle;
    item.Description = string.IsNullOrWhiteSpace(request.Description)
        ? null
        : request.Description.Trim();
    item.IsCompleted = request.IsCompleted;
    item.UpdatedAtUtc = DateTime.UtcNow;

    await db.SaveChangesAsync();

    return Results.Ok(new TodoItemResponse(
        item.Id,
        item.Title,
        item.Description,
        item.IsCompleted,
        item.CreatedAtUtc,
        item.UpdatedAtUtc));
});

todos.MapPatch("/{id:int}/toggle", async (int id, AppDbContext db) =>
{
    var item = await db.TodoItems.FirstOrDefaultAsync(todo => todo.Id == id);
    if (item is null)
    {
        return Results.NotFound();
    }

    item.IsCompleted = !item.IsCompleted;
    item.UpdatedAtUtc = DateTime.UtcNow;
    await db.SaveChangesAsync();

    return Results.Ok(new TodoItemResponse(
        item.Id,
        item.Title,
        item.Description,
        item.IsCompleted,
        item.CreatedAtUtc,
        item.UpdatedAtUtc));
});

todos.MapDelete("/{id:int}", async (int id, AppDbContext db) =>
{
    var item = await db.TodoItems.FirstOrDefaultAsync(todo => todo.Id == id);
    if (item is null)
    {
        return Results.NotFound();
    }

    db.TodoItems.Remove(item);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.Run();

static Dictionary<string, string[]> ValidateTodoInput(string? title, string? description)
{
    var errors = new Dictionary<string, string[]>();

    if (string.IsNullOrWhiteSpace(title))
    {
        errors["title"] = ["Title is required."];
    }
    else if (title.Trim().Length > 120)
    {
        errors["title"] = ["Title must be 120 characters or less."];
    }

    if (!string.IsNullOrWhiteSpace(description) && description.Trim().Length > 600)
    {
        errors["description"] = ["Description must be 600 characters or less."];
    }

    return errors;
}
