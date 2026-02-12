using Microsoft.EntityFrameworkCore;
using Todo.Api.Models;

namespace Todo.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<TodoItem> TodoItems => Set<TodoItem>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<TodoItem>(entity =>
        {
            entity.HasKey(item => item.Id);
            entity.Property(item => item.Title).IsRequired().HasMaxLength(120);
            entity.Property(item => item.Description).HasMaxLength(600);
            entity.Property(item => item.CreatedAtUtc).IsRequired();
            entity.Property(item => item.UpdatedAtUtc).IsRequired();
        });
    }
}
