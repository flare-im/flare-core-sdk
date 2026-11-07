import React from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';
import { IconOutline } from '@ant-design/icons-react-native';
import { styles } from '../../styles';
import type { LoginFormState, SdkStatus } from '../../types';
import { connectionText } from '../../utils';

const gridLines = [0, 1, 2, 3, 4, 5];

export function LoginScreen(props: {
  form: LoginFormState;
  sdkStatus: SdkStatus;
  sdkMessage: string;
  loading: boolean;
  onChange: (patch: Partial<LoginFormState>) => void;
  onLogin: () => void;
}) {
  // Only the identity: where to connect is the bundle's access configuration, the protocol the core's choice.
  const canLogin = Boolean(props.form.userId.trim()) && !props.loading;

  return (
    <View style={styles.loginScreen}>
      <View style={styles.loginHeroPanel}>
        <View pointerEvents="none" style={styles.loginGridLayer}>
          {gridLines.map((line) => (
            <React.Fragment key={line}>
              <View style={[styles.loginGridVertical, { left: `${line * 20}%` }]} />
              <View style={[styles.loginGridHorizontal, { top: `${line * 20}%` }]} />
            </React.Fragment>
          ))}
        </View>
        <View style={styles.loginBrandIcon}>
          <IconOutline name="comment" size={34} color="#7c4dff" />
        </View>
        <Text style={styles.loginBrandName}>flare IM</Text>
        <Text style={styles.loginBrandTagline}>安全、快速的即时通讯</Text>
      </View>

      <View style={styles.loginPanel}>
        <Text style={styles.loginTitle}>欢迎回来</Text>
        <Text style={styles.loginSubtitle}>请输入您的用户 ID 完成登录</Text>

        <View style={styles.loginFieldGroup}>
          <Text style={styles.loginLabel}>用户 ID</Text>
          <View style={styles.loginInputRow}>
            <IconOutline name="user" size={18} color="#9aa1ad" />
            <TextInput
              accessibilityLabel="用户 ID"
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="default"
              onChangeText={(userId) => props.onChange({ userId, token: '' })}
              placeholder="11"
              placeholderTextColor="#6f7581"
              returnKeyType="done"
              style={styles.loginTextInput}
              value={props.form.userId}
            />
          </View>
          <View style={styles.loginHintRow}>
            <IconOutline name="info-circle" size={14} color="#7c4dff" />
            <Text style={styles.loginHintText}>Token 将根据用户 ID 自动生成</Text>
          </View>
        </View>

        <Pressable
          accessibilityRole="button"
          accessibilityState={{ disabled: !canLogin }}
          disabled={!canLogin}
          onPress={props.onLogin}
          style={[styles.loginButton, !canLogin && styles.loginButtonDisabled]}
        >
          <IconOutline name="login" size={18} color="#ffffff" />
          <Text style={styles.loginButtonText}>{props.loading ? '正在登录' : '立即登录'}</Text>
        </Pressable>

        <Text style={styles.loginFootnote}>ID 由管理员分配，可在邀请邮件中查看</Text>
        <Text style={styles.loginFootnote}>仅支持 ID 登录 · 安全连接已启用</Text>
      </View>

      <View style={styles.loginStatusBar}>
        <View style={[styles.loginStatusPill, props.sdkStatus === 'ready' && styles.loginStatusPillReady]}>
          <Text style={styles.loginStatusPillText}>{props.sdkStatus === 'ready' ? '会话活跃' : connectionText(props.sdkStatus)}</Text>
        </View>
        <Text numberOfLines={1} style={styles.loginStatusText}>
          {props.form.userId.trim() || '未登录'} · {props.sdkMessage}
        </Text>
      </View>
    </View>
  );
}
