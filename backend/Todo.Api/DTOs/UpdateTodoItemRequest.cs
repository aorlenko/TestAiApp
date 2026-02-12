using System.ComponentModel.DataAnnotations;

namespace Todo.Api.DTOs;

public record UpdateTodoItemRequest(
    [Required, StringLength(120, MinimumLength = 1)]
    string Title,
    [StringLength(600)]
    string? Description,
    bool IsCompleted);
