# Database Configuration

## PostgreSQL Setup

1. Install PostgreSQL (if not already installed)
2. Create a database for the esports platform:
   ```sql
   CREATE DATABASE esports_platform;
   ```

3. Run the schema migration:
   ```bash
   psql -d esports_platform -f database/schema/esports_platform.sql
   ```

4. (Optional) Seed with sample data:
   ```bash
   psql -d esports_platform -f database/seeds/sample_data.sql
   ```

## Environment Variables

Create a `.env` file in the backend directory with:

```env
DATABASE_URL=postgresql://username:password@localhost:5432/esports_platform
```

## Migration Management

For production use, consider using a migration tool like:
- knex.js
- db-migrate
- TypeORM migrations

## Database Connection (Node.js)

Install the PostgreSQL client:
```bash
npm install pg @types/pg
```

Example connection:
```typescript
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export default pool;
```
