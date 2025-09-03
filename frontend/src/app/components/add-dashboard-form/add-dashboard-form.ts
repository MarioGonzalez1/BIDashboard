import { Component, EventEmitter, Output, Input, OnChanges, SimpleChanges } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { DashboardService, IDashboard } from '../../services/dashboard';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-add-dashboard-form',
  imports: [ReactiveFormsModule, CommonModule],
  templateUrl: './add-dashboard-form.html',
  styleUrl: './add-dashboard-form.scss'
})
export class AddDashboardFormComponent implements OnChanges {
  @Output() dashboardAdded = new EventEmitter<void>();
  @Input() dashboardToEdit: IDashboard | null = null;
  addForm: FormGroup;
  selectedFile: File | null = null;
  categories = ['Operations', 'Finance', 'Accounting', 'Workshop', 'Human Resources', 'Executive & Management'];
  subcategories: { [key: string]: string[] } = {
    'Workshop': ['Forza Transportation', 'Force One Transport'],
    'Human Resources': ['Employee Management', 'Payroll', 'Performance Reviews', 'Recruiting', 'Training'],
    'Executive & Management': ['Executive Dashboard', 'Performance Metrics', 'Strategic Planning', 'Business Intelligence']
  };
  selectedCategory = '';
  isEditMode = false;

  constructor(private fb: FormBuilder, private dashboardService: DashboardService) {
    this.addForm = this.fb.group({
      titulo: ['', Validators.required],
      url_acceso: ['', Validators.required],
      categoria: ['', Validators.required],
      subcategoria: [''],
      descripcion: ['']
    });
    
    // Watch for category changes to reset subcategory
    this.addForm.get('categoria')?.valueChanges.subscribe(categoria => {
      this.selectedCategory = categoria;
      this.addForm.get('subcategoria')?.setValue('');
    });
  }

  ngOnChanges(changes: SimpleChanges) {
    if (changes['dashboardToEdit']) {
      if (this.dashboardToEdit) {
        this.isEditMode = true;
        this.addForm.patchValue({
          titulo: this.dashboardToEdit.titulo,
          url_acceso: this.dashboardToEdit.url_acceso,
          categoria: this.dashboardToEdit.categoria,
          subcategoria: this.dashboardToEdit.subcategoria || '',
          descripcion: this.dashboardToEdit.descripcion || ''
        });
        this.selectedCategory = this.dashboardToEdit.categoria;
      } else {
        this.isEditMode = false;
        this.addForm.reset();
      }
    }
  }

  onFileSelect(event: Event) {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length) { 
      this.selectedFile = input.files[0]; 
    }
  }

  onSubmit() {
    if (!this.addForm.valid) return;
    
    // For edit mode, image is optional. For add mode, image is required
    if (!this.isEditMode && !this.selectedFile) return;
    
    const formData = new FormData();
    Object.keys(this.addForm.value).forEach(key => 
      formData.append(key, this.addForm.value[key]));
    
    if (this.selectedFile) {
      formData.append('screenshot', this.selectedFile);
    }
    
    if (this.isEditMode && this.dashboardToEdit) {
      this.dashboardService.updateDashboard(this.dashboardToEdit.id, formData).subscribe(() => {
        this.dashboardAdded.emit();
        this.resetForm();
      });
    } else {
      this.dashboardService.addDashboard(formData).subscribe(() => {
        this.dashboardAdded.emit();
        this.resetForm();
      });
    }
  }

  resetForm() {
    this.addForm.reset();
    this.selectedFile = null;
    this.isEditMode = false;
  }
  
  onCancel() {
    this.resetForm();
    this.dashboardAdded.emit(); // Emit to close the form
  }
}
