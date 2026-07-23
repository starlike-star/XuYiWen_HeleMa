import { WaterApiError } from '../../api/WaterApi';

@Component
export struct LoginView {
  @Prop loginExpired: boolean = false;
  onLogin: (phone: string, password: string) => Promise<void> = async (_phone: string, _password: string) => {};

  @State private phone: string = '';
  @State private password: string = '';
  @State private errorMessage: string = '';
  @State private isSubmitting: boolean = false;

  private validate(): string {
    if (this.phone.length === 0) return '请输入手机号';
    if (!/^\d+$/.test(this.phone)) return '手机号只能包含数字';
    if (this.phone.length !== 11) return '手机号必须为 11 位';
    if (!/^1[3-9]\d{9}$/.test(this.phone)) return '手机号格式不正确';
    if (this.password.length === 0) return '请输入密码';
    if (this.password.length < 8 || this.password.length > 64 ||
      !/[A-Za-z]/.test(this.password) || !/\d/.test(this.password)) {
      return '密码须为 8～64 位，且至少包含一个字母和一个数字';
    }
    return '';
  }

  private async submit(): Promise<void> {
    if (this.isSubmitting) return;
    this.errorMessage = this.validate();
    if (this.errorMessage.length > 0) return;
    this.isSubmitting = true;
    try {
      await this.onLogin(this.phone, this.password);
    } catch (error) {
      if (error instanceof WaterApiError) {
        if (error.code === 'INVALID_CREDENTIALS') this.errorMessage = '手机号或密码不正确';
        else if (error.code === 'ACCOUNT_LOCKED') this.errorMessage = '失败次数过多，请 15 分钟后重试';
        else if (error.code === 'ACCOUNT_DISABLED') this.errorMessage = '账号已停用，请联系账号管理员';
        else if (error.code === 'NETWORK_ERROR' || error.code === 'SERVICE_UNREACHABLE') {
          this.errorMessage = '网络连接失败，请检查网络后重试';
        } else if (error.code === 'DB_INITIALIZATION_INCOMPLETE' || error.code === 'DB_NOT_CONFIGURED') {
          this.errorMessage = '数据库尚未完成初始化，请联系本地管理员';
        } else if (error.code === 'DB_UNAVAILABLE') {
          this.errorMessage = '数据库暂时不可用，请稍后重试';
        } else this.errorMessage = '服务暂时不可用，请稍后重试';
      } else {
        this.errorMessage = '服务暂时不可用，请稍后重试';
      }
    } finally {
      this.isSubmitting = false;
    }
  }

  build() {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text('喝了吗').fontSize(36).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Text('登录后继续记录你的喝水节奏').fontSize(15).fontColor($r('app.color.text_secondary'))
      }.alignItems(HorizontalAlign.Start).width('100%')

      if (this.loginExpired) {
        Text('登录已过期，请重新登录')
          .fontSize(14).fontColor($r('app.color.warning_text'))
          .padding(12).width('100%').backgroundColor($r('app.color.warning_surface')).borderRadius(14)
      }

      Column({ space: 14 }) {
        TextInput({ placeholder: '中国大陆手机号', text: this.phone })
          .type(InputType.PhoneNumber)
          .maxLength(11)
          .onChange((value: string) => {
            this.phone = value;
            this.errorMessage = '';
          })
          .height(54).padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.surface_input')).fontColor($r('app.color.text_primary')).borderRadius(16)
        TextInput({ placeholder: '密码', text: this.password })
          .type(InputType.Password)
          .maxLength(64)
          .onChange((value: string) => {
            this.password = value;
            this.errorMessage = '';
          })
          .height(54).padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.surface_input')).fontColor($r('app.color.text_primary')).borderRadius(16)
      }.width('100%')

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage).fontSize(13).fontColor($r('app.color.danger_text')).width('100%')
      }

      Button(this.isSubmitting ? '登录中…' : '登录')
        .enabled(!this.isSubmitting)
        .width('100%').height(52).borderRadius(26)
        .fontSize(17).fontWeight(FontWeight.Medium)
        .backgroundColor($r('app.color.accent_primary'))
        .onClick(() => this.submit())

      Text('账号由本地管理员创建；本应用不提供公开注册。')
        .fontSize(12).fontColor($r('app.color.text_tertiary')).textAlign(TextAlign.Center)
    }
    .width('100%').height('100%')
    .padding({ left: 28, right: 28, top: 120 })
    .backgroundColor($r('app.color.page_background'))
  }
}
