import { Request, Response } from 'express';
import { AuthRequest } from '../middleware/auth';

// Mock user database (same as in auth controller)
let users: any[] = [
  {
    id: 1,
    username: 'admin',
    email: 'admin@example.com',
    password: 'hashedpassword',
    createdAt: new Date(),
    stats: {
      totalTournaments: 15,
      wins: 8,
      losses: 7,
      winRate: 53.3,
      totalEarnings: 2500
    }
  }
];

export const getAllUsers = async (req: AuthRequest, res: Response) => {
  try {
    // In a real app, you'd implement pagination and filtering
    const safeUsers = users.map(user => ({
      id: user.id,
      username: user.username,
      email: user.email,
      stats: user.stats
    }));

    res.json({ users: safeUsers });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getUserById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const user = users.find(u => u.id === parseInt(id));

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const safeUser = {
      id: user.id,
      username: user.username,
      email: user.email,
      stats: user.stats
    };

    res.json({ user: safeUser });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateUser = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const updates = req.body;
    const userId = parseInt(id);

    // Users can only update their own profile unless they're admin
    if (req.user.id !== userId && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Not authorized to update this user' });
    }

    const userIndex = users.findIndex(u => u.id === userId);

    if (userIndex === -1) {
      return res.status(404).json({ error: 'User not found' });
    }

    users[userIndex] = { ...users[userIndex], ...updates };

    const safeUser = {
      id: users[userIndex].id,
      username: users[userIndex].username,
      email: users[userIndex].email,
      stats: users[userIndex].stats
    };

    res.json({
      message: 'User updated successfully',
      user: safeUser
    });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const deleteUser = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const userId = parseInt(id);

    // Users can only delete their own account unless they're admin
    if (req.user.id !== userId && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Not authorized to delete this user' });
    }

    const userIndex = users.findIndex(u => u.id === userId);

    if (userIndex === -1) {
      return res.status(404).json({ error: 'User not found' });
    }

    users.splice(userIndex, 1);

    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getUserStats = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const user = users.find(u => u.id === parseInt(id));

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ stats: user.stats });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
};
