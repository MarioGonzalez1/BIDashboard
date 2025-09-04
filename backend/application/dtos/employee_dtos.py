from pydantic import BaseModel, EmailStr, validator
from typing import Optional
from datetime import datetime
from decimal import Decimal
from enum import Enum


class EmploymentStatusEnum(str, Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    TERMINATED = "terminated"
    ON_LEAVE = "on_leave"


class CreateEmployeeRequest(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    phone: Optional[str] = None
    department: str
    position: str
    salary: Decimal
    hire_date: datetime
    status: EmploymentStatusEnum = EmploymentStatusEnum.ACTIVE
    
    @validator('first_name', 'last_name')
    def validate_names(cls, v):
        if not v or not v.strip():
            raise ValueError('Name cannot be empty')
        if len(v.strip()) > 50:
            raise ValueError('Name cannot exceed 50 characters')
        return v.strip().title()
    
    @validator('department', 'position')
    def validate_work_details(cls, v):
        if not v or not v.strip():
            raise ValueError('Field cannot be empty')
        if len(v.strip()) > 100:
            raise ValueError('Field cannot exceed 100 characters')
        return v.strip()
    
    @validator('salary')
    def validate_salary(cls, v):
        if v <= 0:
            raise ValueError('Salary must be positive')
        if v > 9999999.99:
            raise ValueError('Salary exceeds maximum allowed value')
        return v
    
    @validator('phone')
    def validate_phone(cls, v):
        if v and v.strip():
            # Basic phone validation
            phone_digits = ''.join(filter(str.isdigit, v))
            if len(phone_digits) < 10:
                raise ValueError('Phone number must have at least 10 digits')
            return v.strip()
        return v


class UpdateEmployeeRequest(BaseModel):
    first_name: Optional[str]
    last_name: Optional[str]
    email: Optional[EmailStr]
    phone: Optional[str]
    department: Optional[str]
    position: Optional[str]
    salary: Optional[Decimal]
    status: Optional[EmploymentStatusEnum]
    
    @validator('first_name', 'last_name')
    def validate_names(cls, v):
        if v is not None:
            if not v.strip():
                raise ValueError('Name cannot be empty')
            if len(v.strip()) > 50:
                raise ValueError('Name cannot exceed 50 characters')
            return v.strip().title()
        return v
    
    @validator('department', 'position')
    def validate_work_details(cls, v):
        if v is not None:
            if not v.strip():
                raise ValueError('Field cannot be empty')
            if len(v.strip()) > 100:
                raise ValueError('Field cannot exceed 100 characters')
            return v.strip()
        return v
    
    @validator('salary')
    def validate_salary(cls, v):
        if v is not None:
            if v <= 0:
                raise ValueError('Salary must be positive')
            if v > 9999999.99:
                raise ValueError('Salary exceeds maximum allowed value')
        return v
    
    @validator('phone')
    def validate_phone(cls, v):
        if v is not None and v.strip():
            phone_digits = ''.join(filter(str.isdigit, v))
            if len(phone_digits) < 10:
                raise ValueError('Phone number must have at least 10 digits')
            return v.strip()
        return v


class EmployeeResponse(BaseModel):
    id: int
    first_name: str
    last_name: str
    full_name: str
    email: str
    phone: Optional[str]
    department: str
    position: str
    salary: Decimal
    hire_date: datetime
    status: EmploymentStatusEnum
    is_active: bool
    years_of_service: float
    created_by: int
    created_date: datetime
    can_edit: bool = False
    can_delete: bool = False
    
    class Config:
        from_attributes = True
        use_enum_values = True


class EmployeeListResponse(BaseModel):
    employees: list[EmployeeResponse]
    total: int
    departments: list[str]
    active_count: int


class EmployeeStatsResponse(BaseModel):
    total_employees: int
    active_employees: int
    departments_count: int
    department_breakdown: dict[str, int]
    average_salary: Decimal
    average_years_of_service: float