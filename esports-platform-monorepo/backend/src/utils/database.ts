import { Pool } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

// Parse the DATABASE_URL from environment variables
const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  throw new Error('DATABASE_URL environment variable is required');
}

// Parse the connection string
const connectionString = databaseUrl;

// Create connection pool
const pool = new Pool({
  connectionString,
  ssl: {
    rejectUnauthorized: false // Required for Supabase SSL
  },
  max: 20, // Maximum number of clients in the pool
  idleTimeoutMillis: 30000, // Close idle clients after 30 seconds
  connectionTimeoutMillis: 2000, // Return error after 2 seconds if connection could not be established
});

// Test database connection
export const testConnection = async (): Promise<void> => {
  try {
    const client = await pool.connect();
    await client.query('SELECT 1');
    client.release();
    console.log('✅ Database connected successfully');
  } catch (error) {
    console.error('❌ Database connection failed:', error);
    throw error;
  }
};

// Query helper function with error handling
export const query = async (text: string, params?: any[]): Promise<any> => {
  const start = Date.now();
  try {
    const result = await pool.query(text, params);
    const duration = Date.now() - start;
    console.log('Executed query', { text, duration, rows: result.rowCount });
    return result;
  } catch (error) {
    const duration = Date.now() - start;
    console.error('Query failed', { text, duration, error });
    throw error;
  }
};

// Transaction helper
export const transaction = async (callback: (client: any) => Promise<any>): Promise<any> => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

// Close pool (for graceful shutdown)
export const closePool = (): Promise<void> => {
  return pool.end();
};

export default pool;
