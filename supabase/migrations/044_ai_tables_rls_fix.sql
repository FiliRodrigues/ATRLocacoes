-- Fix ai_conversations policies
DROP POLICY IF EXISTS ai_conv_select ON public.ai_conversations;
CREATE POLICY ai_conv_select ON public.ai_conversations
FOR SELECT USING (tenant_id = public.auth_tenant_id() AND user_id = auth.uid());

DROP POLICY IF EXISTS ai_conv_insert ON public.ai_conversations;
CREATE POLICY ai_conv_insert ON public.ai_conversations
FOR INSERT WITH CHECK (tenant_id = public.auth_tenant_id() AND user_id = auth.uid());

DROP POLICY IF EXISTS ai_conv_update ON public.ai_conversations;
CREATE POLICY ai_conv_update ON public.ai_conversations
FOR UPDATE USING (tenant_id = public.auth_tenant_id() AND user_id = auth.uid());

-- Fix ai_messages policies
DROP POLICY IF EXISTS ai_msg_select ON public.ai_messages;
CREATE POLICY ai_msg_select ON public.ai_messages
FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.ai_conversations c WHERE c.id = conversation_id AND c.user_id = auth.uid() AND c.tenant_id = public.auth_tenant_id())
);

DROP POLICY IF EXISTS ai_msg_insert ON public.ai_messages;
CREATE POLICY ai_msg_insert ON public.ai_messages
FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.ai_conversations c WHERE c.id = conversation_id AND c.user_id = auth.uid() AND c.tenant_id = public.auth_tenant_id())
);

-- Fix ai_action_audit policies
DROP POLICY IF EXISTS ai_audit_select ON public.ai_action_audit;
CREATE POLICY ai_audit_select ON public.ai_action_audit
FOR SELECT USING (
  tenant_id = public.auth_tenant_id()
  AND (
    user_id = auth.uid()
    OR (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  )
);
