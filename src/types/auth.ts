export interface Branch {
  id: string
  code: string
  name: string
}

export interface UserRole {
  code: string
  name: string
  branchId: string | null
}

export interface AuthProfile {
  id: string
  employeeNo: string | null
  fullName: string
  email: string | null
  isActive: boolean
  roles: UserRole[]
  branches: Branch[]
}
