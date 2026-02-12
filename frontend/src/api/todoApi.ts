import type { TodoCreateInput, TodoItem, TodoUpdateInput } from '../types/todo';

const baseUrl = '/api/todos';

async function parseResponse<T>(response: Response): Promise<T> {
  if (!response.ok) {
    throw new Error(`Request failed with status ${response.status}`);
  }
  return response.json() as Promise<T>;
}

export async function getTodos(): Promise<TodoItem[]> {
  const response = await fetch(baseUrl);
  return parseResponse<TodoItem[]>(response);
}

export async function createTodo(input: TodoCreateInput): Promise<TodoItem> {
  const response = await fetch(baseUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
  });
  return parseResponse<TodoItem>(response);
}

export async function updateTodo(id: number, input: TodoUpdateInput): Promise<TodoItem> {
  const response = await fetch(`${baseUrl}/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
  });
  return parseResponse<TodoItem>(response);
}

export async function toggleTodo(id: number): Promise<TodoItem> {
  const response = await fetch(`${baseUrl}/${id}/toggle`, {
    method: 'PATCH',
  });
  return parseResponse<TodoItem>(response);
}

export async function deleteTodo(id: number): Promise<void> {
  const response = await fetch(`${baseUrl}/${id}`, {
    method: 'DELETE',
  });
  if (!response.ok) {
    throw new Error(`Request failed with status ${response.status}`);
  }
}
