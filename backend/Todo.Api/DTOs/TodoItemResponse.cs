namespace Todo.Api.DTOs;

public record TodoItemResponse(
    int Id,
    string Title,
    string? Description,
    bool IsCompleted,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc);
