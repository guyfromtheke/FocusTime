import SwiftUI

extension ContentView {
    // MARK: - Tag Manager View
    var tagManagerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Manage Tags")
                    .font(.headline)
                
                Spacer()
                
                Button("Reset") {
                    timerState.sessionHistory.resetTagsToDefaults()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .foregroundColor(.orange)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(timerState.sessionHistory.availableTags) { tag in
                        HStack {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 12, height: 12)
                            
                            Text(tag.name)
                                .font(.caption)
                            
                            Spacer()
                            
                            Button {
                                editingTag = tag
                                editTagName = tag.name
                                editTagColor = tag.color
                                tagEditError = nil
                                showEditTag = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                            
                            if tag.isDefault {
                                Text("default")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 45)
                            } else {
                                Button {
                                    timerState.sessionHistory.removeCustomTag(name: tag.name)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                                .frame(width: 45)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(4)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(maxHeight: 180)
            
            Divider()
            
            if showEditTag, let tag = editingTag {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Edit: \(tag.name)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("Cancel") {
                            showEditTag = false
                            editingTag = nil
                            tagEditError = nil
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                    HStack {
                        TextField("Tag name", text: $editTagName)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        
                        ColorPicker("", selection: $editTagColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 30)
                    }
                    
                    if let error = tagEditError {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }

                    Button("Save Changes") {
                        if !editTagName.isEmpty {
                            let hex = editTagColor.toHex() ?? "#607D8B"
                            let succeeded = timerState.sessionHistory.updateTag(oldName: tag.name, newName: editTagName, newColorHex: hex)
                            if succeeded {
                                showEditTag = false
                                editingTag = nil
                                tagEditError = nil
                            } else {
                                tagEditError = "A tag named \"\(editTagName)\" already exists."
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                    .disabled(editTagName.isEmpty)
                }
                .padding()
                .background(Color.blue.opacity(0.15))
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Custom Tag")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Tag name", text: $newTagName)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        
                        ColorPicker("", selection: $newTagColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 30)
                    }
                    
                    Button("Add Tag") {
                        if !newTagName.isEmpty {
                            let hex = newTagColor.toHex() ?? "#607D8B"
                            timerState.sessionHistory.addCustomTag(name: newTagName, colorHex: hex)
                            newTagName = ""
                            newTagColor = .blue
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(newTagName.isEmpty)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button("← Back") {
                showTagManager = false
                showSettings = true
                showEditTag = false
                editingTag = nil
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
    }
    
}
