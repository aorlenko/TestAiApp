import { type FormEvent, useEffect, useMemo, useState } from 'react';
import {
  createTodo,
  deleteTodo,
  getTodos,
  toggleTodo,
  updateTodo,
} from './api/todoApi';
import type { TodoItem, TodoUpdateInput } from './types/todo';
import './index.css';

type Filter = 'all' | 'active' | 'completed';

function App() {
  const [todos, setTodos] = useState<TodoItem[]>([]);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [filter, setFilter] = useState<Filter>('all');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void loadTodos();
  }, []);

  const filteredTodos = useMemo(() => {
    if (filter === 'active') {
      return todos.filter((todo) => !todo.isCompleted);
    }
    if (filter === 'completed') {
      return todos.filter((todo) => todo.isCompleted);
    }
    return todos;
  }, [todos, filter]);

  const stats = useMemo(() => {
    const completed = todos.filter((todo) => todo.isCompleted).length;
    return { total: todos.length, completed, active: todos.length - completed };
  }, [todos]);

  async function loadTodos() {
    try {
      setLoading(true);
      setError(null);
      const result = await getTodos();
      setTodos(result);
    } catch {
      setError('Could not load tasks. Check backend connection.');
    } finally {
      setLoading(false);
    }
  }

  async function handleCreateTodo(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!title.trim()) {
      return;
    }

    try {
      setSaving(true);
      setError(null);
      const created = await createTodo({ title, description });
      setTodos((prev) => [created, ...prev]);
      setTitle('');
      setDescription('');
    } catch {
      setError('Could not create task.');
    } finally {
      setSaving(false);
    }
  }

  async function handleToggleTodo(id: number) {
    try {
      setError(null);
      const updated = await toggleTodo(id);
      setTodos((prev) => prev.map((todo) => (todo.id === id ? updated : todo)));
    } catch {
      setError('Could not update task status.');
    }
  }

  async function handleDeleteTodo(id: number) {
    try {
      setError(null);
      await deleteTodo(id);
      setTodos((prev) => prev.filter((todo) => todo.id !== id));
    } catch {
      setError('Could not delete task.');
    }
  }

  async function handleEditTodo(id: number, input: TodoUpdateInput) {
    try {
      setError(null);
      const updated = await updateTodo(id, input);
      setTodos((prev) => prev.map((todo) => (todo.id === id ? updated : todo)));
    } catch {
      setError('Could not save task changes.');
    }
  }

  return (
    <main className="app-shell">
      <section className="todo-card">
        <header className="todo-header">
          <div>
            <p className="kicker">Hackathon Todo App</p>
            <h1>Stay focused, ship faster</h1>
          </div>
          <button className="ghost-button" onClick={() => void loadTodos()} type="button">
            Refresh
          </button>
        </header>

        <form className="todo-form" onSubmit={handleCreateTodo}>
          <input
            className="input"
            maxLength={120}
            onChange={(event) => setTitle(event.target.value)}
            placeholder="Task title"
            required
            value={title}
          />
          <textarea
            className="input"
            maxLength={600}
            onChange={(event) => setDescription(event.target.value)}
            placeholder="Description (optional)"
            rows={2}
            value={description}
          />
          <button className="primary-button" disabled={saving || !title.trim()} type="submit">
            {saving ? 'Adding...' : 'Add task'}
          </button>
        </form>

        <section className="stats-grid">
          <article>
            <p>Total</p>
            <strong>{stats.total}</strong>
          </article>
          <article>
            <p>Active</p>
            <strong>{stats.active}</strong>
          </article>
          <article>
            <p>Completed</p>
            <strong>{stats.completed}</strong>
          </article>
        </section>

        <nav className="filter-row" aria-label="Todo filters">
          {(['all', 'active', 'completed'] as const).map((item) => (
            <button
              className={item === filter ? 'chip active' : 'chip'}
              key={item}
              onClick={() => setFilter(item)}
              type="button"
            >
              {item}
            </button>
          ))}
        </nav>

        {error && <p className="error-banner">{error}</p>}

        <section className="todo-list" aria-live="polite">
          {loading && <p className="state-line">Loading tasks...</p>}
          {!loading && filteredTodos.length === 0 && (
            <p className="state-line">No tasks in this view yet.</p>
          )}
          {!loading &&
            filteredTodos.map((todo) => (
              <TodoRow
                key={todo.id}
                onDelete={handleDeleteTodo}
                onEdit={handleEditTodo}
                onToggle={handleToggleTodo}
                todo={todo}
              />
            ))}
        </section>
      </section>
    </main>
  );
}

type TodoRowProps = {
  todo: TodoItem;
  onToggle: (id: number) => Promise<void>;
  onDelete: (id: number) => Promise<void>;
  onEdit: (id: number, input: TodoUpdateInput) => Promise<void>;
};

function TodoRow({ todo, onToggle, onDelete, onEdit }: TodoRowProps) {
  const [editing, setEditing] = useState(false);
  const [draftTitle, setDraftTitle] = useState(todo.title);
  const [draftDescription, setDraftDescription] = useState(todo.description ?? '');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setDraftTitle(todo.title);
    setDraftDescription(todo.description ?? '');
  }, [todo.description, todo.title]);

  async function saveEdit() {
    if (!draftTitle.trim()) {
      return;
    }

    try {
      setSaving(true);
      await onEdit(todo.id, {
        title: draftTitle,
        description: draftDescription,
        isCompleted: todo.isCompleted,
      });
      setEditing(false);
    } finally {
      setSaving(false);
    }
  }

  return (
    <article className={todo.isCompleted ? 'todo-item completed' : 'todo-item'}>
      <label className="checkbox-wrap">
        <input checked={todo.isCompleted} onChange={() => void onToggle(todo.id)} type="checkbox" />
      </label>

      <div className="todo-body">
        {editing ? (
          <>
            <input
              className="input"
              maxLength={120}
              onChange={(event) => setDraftTitle(event.target.value)}
              value={draftTitle}
            />
            <textarea
              className="input"
              maxLength={600}
              onChange={(event) => setDraftDescription(event.target.value)}
              rows={2}
              value={draftDescription}
            />
          </>
        ) : (
          <>
            <h3>{todo.title}</h3>
            {todo.description && <p>{todo.description}</p>}
          </>
        )}
      </div>

      <div className="item-actions">
        {editing ? (
          <>
            <button className="mini-button" disabled={saving} onClick={() => void saveEdit()} type="button">
              Save
            </button>
            <button className="mini-button secondary" onClick={() => setEditing(false)} type="button">
              Cancel
            </button>
          </>
        ) : (
          <>
            <button className="mini-button" onClick={() => setEditing(true)} type="button">
              Edit
            </button>
            <button className="mini-button danger" onClick={() => void onDelete(todo.id)} type="button">
              Delete
            </button>
          </>
        )}
      </div>
    </article>
  );
}

export default App;
