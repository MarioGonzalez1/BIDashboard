import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { IDashboard } from '../../services/dashboard';
import { AuthService } from '../../services/auth';
import { TooltipDirective } from '../../directives/tooltip.directive';

@Component({
  selector: 'app-dashboard-card',
  imports: [CommonModule, TooltipDirective],
  templateUrl: './dashboard-card.html',
  styleUrl: './dashboard-card.scss'
})
export class DashboardCardComponent {
  @Input() dashboard!: IDashboard;
  @Output() editDashboard = new EventEmitter<IDashboard>();
  @Output() deleteDashboard = new EventEmitter<number>();
  
  constructor(public authService: AuthService) {}
  
  openLink() {
    window.open(this.dashboard.url_acceso, '_blank');
  }
  
  onEdit() {
    this.editDashboard.emit(this.dashboard);
  }
  
  onDelete() {
    if (confirm(`¿Estás seguro de que quieres eliminar el dashboard "${this.dashboard.titulo}"?`)) {
      this.deleteDashboard.emit(this.dashboard.id);
    }
  }
}
