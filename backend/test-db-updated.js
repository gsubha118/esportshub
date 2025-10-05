const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  // No password for local development
  ssl: false,
});

async function testConnection() {
  try {
    console.log('Testing database connection with updated config...');
    
    const client = await pool.connect();
    console.log('✅ Database connected successfully');
    
    const result = await client.query('SELECT COUNT(*) FROM users');
    console.log('User count:', result.rows[0].count);
    
    client.release();
    await pool.end();
    process.exit(0);
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    process.exit(1);
  }
}

testConnection();