import { Component } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { AuthService } from '../../services/auth';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-login',
  templateUrl: './login.html',
  styleUrls: ['./login.scss'],
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule]
})
export class LoginComponent {
  loginForm: FormGroup;
  isLoading = false;
  errorMessage = '';
  showRegister = false;

  constructor(
    private fb: FormBuilder,
    private authService: AuthService
  ) {
    this.loginForm = this.fb.group({
      username: ['', [Validators.required]],
      password: ['', [Validators.required, Validators.minLength(6)]]
    });
  }

  onSubmit(): void {
    if (this.loginForm.valid) {
      this.isLoading = true;
      this.errorMessage = '';
      
      const credentials = this.loginForm.value;
      
      if (this.showRegister) {
        this.authService.register(credentials).subscribe({
          next: (response) => {
            alert('Registration successful! Please login.');
            this.showRegister = false;
            this.isLoading = false;
          },
          error: (error) => {
            this.errorMessage = error.error?.detail || 'Registration failed';
            this.isLoading = false;
          }
        });
      } else {
        this.authService.login(credentials).subscribe({
          next: (response) => {
            this.isLoading = false;
            window.location.reload();
          },
          error: (error) => {
            this.errorMessage = error.error?.detail || 'Login failed';
            this.isLoading = false;
          }
        });
      }
    }
  }

  toggleMode(): void {
    this.showRegister = !this.showRegister;
    this.errorMessage = '';
    this.loginForm.reset();
  }
}