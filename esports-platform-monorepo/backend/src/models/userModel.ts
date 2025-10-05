import { query } from '../utils/database';

export interface User {
  id: string;
  email: string;
  role: 'player' | 'organizer' | 'admin';
  created_at: Date;
}

export interface UserWithPassword extends User {
  password_hash: string;
}

export class UserModel {
  static async findByEmail(email: string): Promise<UserWithPassword | null> {
    const result = await query(`
      SELECT id, email, role, created_at, password_hash
      FROM users
      WHERE email = $1
    `, [email]);

    return result.rows[0] || null;
  }

  static async findById(id: string): Promise<User | null> {
    const result = await query(`
      SELECT id, email, role, created_at
      FROM users
      WHERE id = $1
    `, [id]);

    return result.rows[0] || null;
  }

  static async create(userData: {
    email: string;
    password_hash: string;
    role: 'player' | 'organizer' | 'admin';
  }): Promise<User> {
    const result = await query(`
      INSERT INTO users (email, role, password_hash)
      VALUES ($1, $2, $3)
      RETURNING id, email, role, created_at
    `, [userData.email, userData.role, userData.password_hash]);

    return result.rows[0];
  }

  static async update(id: string, updates: Partial<Pick<User, 'email' | 'role'>>): Promise<User | null> {
    const fields = Object.keys(updates);
    const values = Object.values(updates);

    if (fields.length === 0) {
      return this.findById(id);
    }

    const setClause = fields.map((field, index) => `${field} = $${index + 1}`).join(', ');
    const queryStr = `
      UPDATE users
      SET ${setClause}
      WHERE id = $${fields.length + 1}
      RETURNING id, email, role, created_at
    `;

    const result = await query(queryStr, [...values, id]);
    return result.rows[0] || null;
  }

  static async delete(id: string): Promise<boolean> {
    const result = await query('DELETE FROM users WHERE id = $1', [id]);
    return result.rowCount > 0;
  }

  static async findAll(): Promise<User[]> {
    const result = await query(`
      SELECT id, email, role, created_at
      FROM users
      ORDER BY created_at DESC
    `);

    return result.rows;
  }
}