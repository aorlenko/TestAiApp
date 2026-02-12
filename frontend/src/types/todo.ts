export type TodoItem = {
  id: number;
  title: string;
  description: string | null;
  isCompleted: boolean;
  createdAtUtc: string;
  updatedAtUtc: string;
};

export type TodoCreateInput = {
  title: string;
  description?: string;
};

export type TodoUpdateInput = {
  title: string;
  description?: string;
  isCompleted: boolean;
};
