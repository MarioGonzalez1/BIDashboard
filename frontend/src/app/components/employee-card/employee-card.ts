import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { IEmployee } from '../../services/hr';
import { AuthService } from '../../services/auth';

@Component({
  selector: 'app-employee-card',
  imports: [CommonModule],
  templateUrl: './employee-card.html',
  styleUrl: './employee-card.scss'
})
export class EmployeeCardComponent {
  @Input() employee!: IEmployee;
  @Output() editEmployee = new EventEmitter<IEmployee>();
  @Output() deleteEmployee = new EventEmitter<number>();
  
  constructor(public authService: AuthService) {}
  
  onEdit() {
    this.editEmployee.emit(this.employee);
  }
  
  onDelete() {
    if (confirm(`¿Estás seguro de que quieres eliminar el empleado "${this.employee.firstName} ${this.employee.lastName}"?`)) {
      this.deleteEmployee.emit(this.employee.id);
    }
  }

  getStatusBadgeClass(): string {
    return this.employee.status === 'active' ? 'status-active' : 'status-inactive';
  }
}