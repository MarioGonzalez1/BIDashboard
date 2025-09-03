import { Component, EventEmitter, Output, Input, OnChanges, SimpleChanges } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { HRService, IEmployee } from '../../services/hr';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-add-employee-form',
  imports: [ReactiveFormsModule, CommonModule],
  templateUrl: './add-employee-form.html',
  styleUrl: './add-employee-form.scss'
})
export class AddEmployeeFormComponent implements OnChanges {
  @Output() employeeAdded = new EventEmitter<void>();
  @Input() employeeToEdit: IEmployee | null = null;
  addForm: FormGroup;
  departments = ['Human Resources', 'Finance', 'Operations', 'IT', 'Marketing', 'Sales', 'Legal', 'Administration'];
  positions = ['Manager', 'Senior Developer', 'Developer', 'Analyst', 'Specialist', 'Coordinator', 'Assistant', 'Director', 'VP'];
  isEditMode = false;

  constructor(private fb: FormBuilder, private hrService: HRService) {
    this.addForm = this.fb.group({
      firstName: ['', Validators.required],
      lastName: ['', Validators.required],
      email: ['', [Validators.required, Validators.email]],
      position: ['', Validators.required],
      department: ['', Validators.required],
      hireDate: ['', Validators.required],
      salary: ['', [Validators.required, Validators.min(0)]],
      status: ['active', Validators.required],
      phone: [''],
      address: ['']
    });
  }

  ngOnChanges(changes: SimpleChanges) {
    if (changes['employeeToEdit']) {
      if (this.employeeToEdit) {
        this.isEditMode = true;
        this.addForm.patchValue({
          firstName: this.employeeToEdit.firstName,
          lastName: this.employeeToEdit.lastName,
          email: this.employeeToEdit.email,
          position: this.employeeToEdit.position,
          department: this.employeeToEdit.department,
          hireDate: this.employeeToEdit.hireDate,
          salary: this.employeeToEdit.salary,
          status: this.employeeToEdit.status,
          phone: this.employeeToEdit.phone || '',
          address: this.employeeToEdit.address || ''
        });
      } else {
        this.isEditMode = false;
        this.addForm.reset();
        this.addForm.patchValue({ status: 'active' });
      }
    }
  }

  onSubmit() {
    if (!this.addForm.valid) return;
    
    const employeeData = this.addForm.value;
    
    if (this.isEditMode && this.employeeToEdit) {
      this.hrService.updateEmployee(this.employeeToEdit.id, employeeData).subscribe(() => {
        this.employeeAdded.emit();
        this.resetForm();
      });
    } else {
      this.hrService.addEmployee(employeeData).subscribe(() => {
        this.employeeAdded.emit();
        this.resetForm();
      });
    }
  }

  resetForm() {
    this.addForm.reset();
    this.addForm.patchValue({ status: 'active' });
    this.isEditMode = false;
  }
  
  onCancel() {
    this.resetForm();
    this.employeeAdded.emit();
  }

  getFormTitle(): string {
    return this.isEditMode ? 'Editar Empleado' : 'Agregar Empleado';
  }

  getSubmitButtonText(): string {
    return this.isEditMode ? 'Actualizar' : 'Agregar';
  }
}