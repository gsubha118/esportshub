import React from 'react';
import { Navigate } from 'react-router-dom';
import { useRBAC, Permission, UserRole } from '../hooks/useRBAC';

interface ProtectedRouteProps {
  children: React.ReactNode;
  permission?: Permission;
  role?: UserRole;
  requireAuth?: boolean;
  fallbackPath?: string;
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  permission,
  role,
  requireAuth = true,
  fallbackPath = '/login'
}) => {
  const { isAuthenticated, hasPermission, hasRole } = useRBAC();

  // Check authentication first if required
  if (requireAuth && !isAuthenticated) {
    return <Navigate to={fallbackPath} replace />;
  }

  // Check role if specified
  if (role && !hasRole(role)) {
    return <Navigate to="/unauthorized" replace />;
  }

  // Check permission if specified
  if (permission && !hasPermission(permission)) {
    return <Navigate to="/unauthorized" replace />;
  }

  return <>{children}</>;
};
