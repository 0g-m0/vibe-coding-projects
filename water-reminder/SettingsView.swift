import SwiftUI

struct SettingsView: View {
    @ObservedObject var store = RemindersStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("健康提醒")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                ForEach($store.reminders) { $r in
                    CardView(reminder: $r)
                }

                MeetingModeCard(meetingMode: $store.meetingMode)

                HStack {
                    Spacer()
                    Button {
                        store.restoreDefaults()
                    } label: {
                        Label("恢复默认（60 分钟）", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.accentColor)
                }
                .padding(.horizontal, 4)
            }
            .padding(20)
        }
        .frame(width: 480, height: 560)
    }
}

struct CardView: View {
    @Binding var reminder: RemindersStore.Reminder

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(reminder.emoji)
                    .font(.system(size: 22))
                TextField("名称", text: $reminder.name)
                    .font(.body)
                    .textFieldStyle(.plain)
                Spacer()
                Toggle("", isOn: $reminder.enabled)
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
                    .controlSize(.small)
            }

            Divider()

            HStack {
                Text("间隔")
                    .foregroundStyle(.secondary)
                    .font(.body)
                TextField("",
                    value: $reminder.intervalMinutes,
                    formatter: NumberFormatter(),
                    onEditingChanged: { _ in
                        if reminder.intervalMinutes < 1 { reminder.intervalMinutes = 1 }
                    })
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)
                Text("分钟")
                    .foregroundStyle(.secondary)
                    .font(.body)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(["5", "15", "30", "60", "120"], id: \.self) { tag in
                        Button(tag) {
                            reminder.intervalMinutes = Int(tag) ?? 60
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(reminder.intervalMinutes == Int(tag) ? .accentColor : .secondary)
                    }
                }
            }

            HStack {
                Text("提醒")
                    .foregroundStyle(.secondary)
                    .font(.body)
                TextField("提示内容", text: $reminder.message)
                    .textFieldStyle(.plain)
                    .font(.body)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .opacity(reminder.enabled ? 1.0 : 0.5)
    }
}

struct MeetingModeCard: View {
    @Binding var meetingMode: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("🎤")
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text("开会模式")
                    .font(.body.bold())
                Text("开启后所有通知静默，适合投屏/演示场景")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $meetingMode)
                .toggleStyle(SwitchToggleStyle())
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .opacity(meetingMode ? 1.0 : 0.7)
    }
}