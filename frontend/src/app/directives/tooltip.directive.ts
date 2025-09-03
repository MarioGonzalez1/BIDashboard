import { Directive, Input, ElementRef, HostListener, Renderer2, OnDestroy } from '@angular/core';

@Directive({
  selector: '[appTooltip]',
  standalone: true
})
export class TooltipDirective implements OnDestroy {
  @Input('appTooltip') tooltipTitle: string = '';
  @Input() tooltipDescription: string = '';
  @Input() placement: string = 'top';
  @Input() delay: number = 300;

  private tooltip: HTMLElement | null = null;
  private showTimeout: any;
  private hideTimeout: any;

  constructor(private el: ElementRef, private renderer: Renderer2) {}

  @HostListener('mouseenter') onMouseEnter() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
    }
    this.showTimeout = setTimeout(() => {
      this.show();
    }, this.delay);
  }

  @HostListener('mouseleave') onMouseLeave() {
    if (this.showTimeout) {
      clearTimeout(this.showTimeout);
    }
    this.hideTimeout = setTimeout(() => {
      this.hide();
    }, 100);
  }

  private show() {
    if (this.tooltip) {
      return;
    }

    this.tooltip = this.renderer.createElement('div');
    this.renderer.addClass(this.tooltip, 'tooltip');
    this.renderer.addClass(this.tooltip, `tooltip-${this.placement}`);

    const tooltipContent = this.renderer.createElement('div');
    this.renderer.addClass(tooltipContent, 'tooltip-content');

    if (this.tooltipTitle) {
      const titleElement = this.renderer.createElement('div');
      this.renderer.addClass(titleElement, 'tooltip-title');
      this.renderer.setProperty(titleElement, 'textContent', this.tooltipTitle);
      this.renderer.appendChild(tooltipContent, titleElement);
    }

    if (this.tooltipDescription) {
      const descElement = this.renderer.createElement('div');
      this.renderer.addClass(descElement, 'tooltip-description');
      this.renderer.setProperty(descElement, 'textContent', this.tooltipDescription);
      this.renderer.appendChild(tooltipContent, descElement);
    }

    this.renderer.appendChild(this.tooltip, tooltipContent);
    this.renderer.appendChild(document.body, this.tooltip);

    const hostPos = this.el.nativeElement.getBoundingClientRect();
    const tooltipPos = this.tooltip!.getBoundingClientRect();

    let top: number, left: number;

    if (this.placement === 'top') {
      top = hostPos.top - tooltipPos.height - 10;
      left = hostPos.left + (hostPos.width - tooltipPos.width) / 2;
    } else if (this.placement === 'bottom') {
      top = hostPos.bottom + 10;
      left = hostPos.left + (hostPos.width - tooltipPos.width) / 2;
    } else if (this.placement === 'left') {
      top = hostPos.top + (hostPos.height - tooltipPos.height) / 2;
      left = hostPos.left - tooltipPos.width - 10;
    } else { // right
      top = hostPos.top + (hostPos.height - tooltipPos.height) / 2;
      left = hostPos.right + 10;
    }

    // Keep tooltip within viewport
    if (left < 0) left = 10;
    if (left + tooltipPos.width > window.innerWidth) {
      left = window.innerWidth - tooltipPos.width - 10;
    }
    if (top < 0) top = 10;
    if (top + tooltipPos.height > window.innerHeight) {
      top = hostPos.top - tooltipPos.height - 10;
    }

    this.renderer.setStyle(this.tooltip, 'top', `${top + window.pageYOffset}px`);
    this.renderer.setStyle(this.tooltip, 'left', `${left + window.pageXOffset}px`);
    this.renderer.addClass(this.tooltip, 'tooltip-show');
  }

  private hide() {
    if (this.tooltip) {
      this.renderer.removeChild(document.body, this.tooltip);
      this.tooltip = null;
    }
  }

  ngOnDestroy() {
    if (this.showTimeout) {
      clearTimeout(this.showTimeout);
    }
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
    }
    this.hide();
  }
}