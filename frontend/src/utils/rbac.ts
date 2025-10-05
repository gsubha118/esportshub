export type UserRole = 'player' | 'organizer' | 'admin';

export interface User {
  id: string;
  email: string;
  username: string;
  role: UserRole;
  created_at: string;
}

export type Permission =
  | 'create_event'
  | 'view_dashboard'
  | 'join_event'
  | 'manage_users'
  | 'view_all_events';

export class RBAC {
  static hasPermission(user: User | null, permission: Permission): boolean {
    if (!user) return false;

    const rolePermissions: Record<UserRole, Permission[]> = {
      player: ['join_event'],
      organizer: ['create_event', 'view_dashboard', 'join_event'],
      admin: ['create_event', 'view_dashboard', 'join_event', 'manage_users', 'view_all_events']
    };

    return rolePermissions[user.role]?.includes(permission) ?? false;
  }

  static hasRole(user: User | null, role: UserRole): boolean {
    return user?.role === role;
  }

  static isOrganizer(user: User | null): boolean {
    return this.hasRole(user, 'organizer') || this.hasRole(user, 'admin');
  }

  static isAdmin(user: User | null): boolean {
    return this.hasRole(user, 'admin');
  }

  static canCreateEvent(user: User | null): boolean {
    return this.hasPermission(user, 'create_event');
  }

  static canViewDashboard(user: User | null): boolean {
    return this.hasPermission(user, 'view_dashboard');
  }

  static canJoinEvent(user: User | null): boolean {
    return this.hasPermission(user, 'join_event');
  }
}
